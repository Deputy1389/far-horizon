from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import zlib
from pathlib import Path

TARGETS = {
    "sand": "texture/tatt_sand_bumpy_a1.dds",
    "sandNormal": "texture/tatt_sand_bumpy_a1_n.dds",
    "wall": "texture/tatt_stco_player_wall.dds",
    "wallDetail": "texture/tatt_stco_player_wall_detlb.dds",
    "floor": "texture/tatt_stco_player_floor_c.dds",
    "capitalWall": "texture/intr_cptl_tatt_wall_trim_a1.dds",
    "capitalStair": "texture/intr_cptl_tatt_stair.dds",
    "concrete": "texture/impl_concrete_a.dds",
    "concreteDetail": "texture/impl_concrete_detail_a.dds",
    "metal": "texture/ins_all_metl_gray.dds",
    "metalVents": "texture/ins_all_metl_gray_vents_a1.dds",
}


def candidate_roots(explicit: str | None) -> list[Path]:
    roots: list[Path] = []
    if explicit:
        roots.append(Path(explicit))

    for raw in [
        r"C:\SWG Restoration",
        r"C:\Program Files\SWG Restoration",
        r"C:\Program Files (x86)\SWG Restoration",
        os.path.join(os.environ.get("ProgramFiles", ""), "SWG Restoration"),
        os.path.join(os.environ.get("ProgramFiles(x86)", ""), "SWG Restoration"),
    ]:
        if raw:
            roots.append(Path(raw))

    for letter in "DEFGHIJKLMNOPQRSTUVWXYZ":
        roots.append(Path(f"{letter}:\\SWG Restoration"))

    seen = set()
    found = []
    for root in roots:
        key = str(root).lower()
        if key in seen:
            continue
        seen.add(key)
        if root.exists():
            found.append(root)
    return found


def _zlib_decompress(data: bytes) -> bytes:
    try:
        return zlib.decompress(data)
    except zlib.error:
        return zlib.decompress(data, -zlib.MAX_WBITS)


def _looks_like_zlib(data: bytes) -> bool:
    if len(data) < 2:
        return False
    cmf, flg = data[0], data[1]
    return (cmf & 0x0F) == 8 and (cmf >> 4) <= 7 and (((cmf << 8) | flg) % 31) == 0 and not (flg & 0x20)


def decode_toc(raw: bytes, compressor: int, record_count: int):
    """Mirror SWG's SearchTree/Nuna TOC recovery behavior."""
    attempts = []
    if compressor != 0:
        try:
            attempts.append(_zlib_decompress(raw))
        except Exception:
            pass
        attempts.append(raw)
    else:
        attempts.append(raw)
        if _looks_like_zlib(raw):
            try:
                attempts.append(_zlib_decompress(raw))
            except Exception:
                pass

    for blob in attempts:
        if not blob or record_count <= 0:
            continue

        if len(blob) % record_count == 0:
            stride = len(blob) // record_count
            if stride >= 24:
                return blob, stride

        # Community v0006 archives can include trailing slack. Trim to a
        # uniform row layout, but never below the 24-byte SearchTree entry.
        trimmed = len(blob) - (len(blob) % record_count)
        if trimmed >= record_count * 24:
            stride = trimmed // record_count
            if stride >= 24:
                return blob[:trimmed], stride

    return None


def decode_name_block(raw: bytes, compressor: int, uncompressed_size: int):
    """Mirror SWG's name-block decode with conservative fallbacks."""
    if uncompressed_size <= 0:
        return None

    if compressor != 0:
        try:
            decoded = _zlib_decompress(raw)
            if len(decoded) >= uncompressed_size:
                return decoded[:uncompressed_size]
        except Exception:
            pass
        if len(raw) == uncompressed_size:
            return raw
        return None

    if len(raw) >= uncompressed_size:
        return raw[:uncompressed_size]

    if _looks_like_zlib(raw):
        try:
            decoded = _zlib_decompress(raw)
            if len(decoded) >= uncompressed_size:
                return decoded[:uncompressed_size]
        except Exception:
            pass

    return None


def read_tre_index(tre_path: Path):
    with tre_path.open("rb") as f:
        header = f.read(36)
        if len(header) != 36:
            return None

        if header[:4] not in (b"EERT", b"TREE"):
            return None

        raw_version = header[4:8].decode("ascii", errors="ignore")
        version = raw_version if raw_version in {"4000", "5000", "6000", "0004", "0005", "0006"} else raw_version[::-1]

        record_count, toc_offset, toc_comp, toc_size, name_comp, name_size, name_uncompressed = struct.unpack_from(
            "<7I", header, 8
        )
        if not record_count or record_count > 2_000_000 or not toc_size or not name_uncompressed:
            return None

        # SearchTree reads exactly header.sizeOfTOC bytes from tocOffset.
        f.seek(toc_offset)
        toc_on_disk = f.read(toc_size)
        if len(toc_on_disk) != toc_size:
            return None

        decoded_toc = decode_toc(toc_on_disk, toc_comp, record_count)
        if not decoded_toc:
            return None
        toc_blob, stride = decoded_toc

        # Name block begins after the STORED TOC bytes, regardless of whether
        # the TOC expands to a larger uncompressed buffer.
        name_block_offset = toc_offset + toc_size
        f.seek(name_block_offset)
        name_read_size = name_size if name_comp != 0 else name_uncompressed
        name_on_disk = f.read(name_read_size)
        if len(name_on_disk) != name_read_size:
            return None

        names = decode_name_block(name_on_disk, name_comp, name_uncompressed)
        if names is None:
            return None

        entries = {}
        valid_rows = 0
        for i in range(record_count):
            off = i * stride
            if off + 24 > len(toc_blob):
                break

            _crc, uncompressed_size, file_offset, compression, compressed_size, name_offset = struct.unpack_from(
                "<6I", toc_blob, off
            )
            if name_offset >= len(names):
                continue

            end = names.find(b"\x00", name_offset)
            if end == -1:
                continue

            virtual_path = names[name_offset:end].decode("utf-8", errors="ignore")
            virtual_path = virtual_path.replace("\\", "/").strip("/").lower()

            # Reject obviously corrupt name offsets instead of letting garbage
            # strings collapse thousands of rows into a misleading dictionary.
            if not virtual_path or len(virtual_path) > 512:
                continue
            if any(ord(ch) < 32 for ch in virtual_path):
                continue

            entries[virtual_path] = {
                "uncompressed_size": uncompressed_size,
                "file_offset": file_offset,
                "compression": compression,
                "compressed_size": compressed_size,
            }
            valid_rows += 1

        if not entries:
            return None

        return {
            "version": version,
            "entries": entries,
            "record_count": record_count,
            "valid_rows": valid_rows,
            "stride": stride,
            "toc_compressor": toc_comp,
            "name_compressor": name_comp,
        }

def copy_loose(root: Path, virtual_path: str, destination: Path) -> bool:
    candidate = root.joinpath(*virtual_path.split("/"))
    if candidate.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(candidate.read_bytes())
        return True

    # Restoration can place overrides in nested patch/mod folders.
    wanted = Path(virtual_path).name.lower()
    for loose in root.rglob("*"):
        if loose.is_file() and loose.name.lower() == wanted:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(loose.read_bytes())
            return True
    return False


def extract_from_tre(tre_path: Path, entry: dict, destination: Path) -> bool:
    try:
        with tre_path.open("rb") as f:
            f.seek(entry["file_offset"])
            stored_size = entry["compressed_size"] if entry["compression"] else entry["uncompressed_size"]
            packed = f.read(stored_size)
        data = _zlib_decompress(packed) if entry["compression"] else packed
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        return True
    except Exception:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Import a curated SWG texture set from a local client install.")
    parser.add_argument("--source", "-s", help="Path to your SWG Restoration client folder.")
    args = parser.parse_args()

    roots = candidate_roots(args.source)
    if not roots:
        print("Could not find an SWG Restoration install automatically.", file=sys.stderr)
        print(r'Run: py tools\import_swg_assets.py --source "C:\path\to\SWG Restoration"', file=sys.stderr)
        return 2

    source = roots[0]
    print(f"Using SWG client: {source}")

    project_root = Path(__file__).resolve().parents[1]
    output_root = project_root / "assets" / "local-swg"
    texture_root = output_root / "texture"
    texture_root.mkdir(parents=True, exist_ok=True)

    pending = dict(TARGETS)
    found: dict[str, str] = {}

    for role, virtual_path in list(pending.items()):
        destination = texture_root / Path(virtual_path).name
        if copy_loose(source, virtual_path, destination):
            found[role] = f"./assets/local-swg/texture/{destination.name}"
            pending.pop(role)
            print(f"loose  {virtual_path}")

    tre_files = sorted(
        [p for p in source.rglob("*") if p.is_file() and p.suffix.lower() == ".tre"],
        key=lambda p: str(p).lower(),
    )
    print(f"Scanning {len(tre_files)} TRE archives for {len(pending)} texture(s)...")

    parsed_archives = 0
    parsed_entries = 0
    parsed_valid_rows = 0
    versions: dict[str, int] = {}
    strides: dict[int, int] = {}
    compressors: dict[str, int] = {}
    sample_paths: list[str] = []

    # Search all archives. Later files are allowed to replace earlier matches,
    # which approximates the client's patch/override behavior.
    matches: dict[str, tuple[Path, dict, str]] = {}

    for tre_path in tre_files:
        try:
            archive = read_tre_index(tre_path)
        except Exception as exc:
            archive = None

        if not archive:
            continue

        parsed_archives += 1
        entries = archive["entries"]
        parsed_entries += archive.get("record_count", len(entries))
        parsed_valid_rows += archive.get("valid_rows", len(entries))
        versions[archive["version"]] = versions.get(archive["version"], 0) + 1
        strides[archive.get("stride", 24)] = strides.get(archive.get("stride", 24), 0) + 1
        comp_key = f'toc{archive.get("toc_compressor", "?")}/name{archive.get("name_compressor", "?")}'
        compressors[comp_key] = compressors.get(comp_key, 0) + 1

        if len(sample_paths) < 8:
            texture_samples=[p for p in entries if p.startswith("texture/")]
            if texture_samples:
                sample_paths.extend(texture_samples[: 8 - len(sample_paths)])
            elif not sample_paths:
                sample_paths.extend(list(entries)[:8])

        by_basename: dict[str, list[str]] = {}
        for archive_path in entries:
            by_basename.setdefault(Path(archive_path).name.lower(), []).append(archive_path)

        for role, virtual_path in pending.items():
            exact = virtual_path.lower()
            matched_path = exact if exact in entries else None

            # Restoration/patch archives occasionally move an asset while
            # retaining its original basename. Use basename matching as a
            # conservative fallback.
            if matched_path is None:
                candidates = by_basename.get(Path(exact).name.lower(), [])
                if len(candidates) == 1:
                    matched_path = candidates[0]

            if matched_path is not None:
                matches[role] = (tre_path, entries[matched_path], matched_path)

    print(
        f"Parsed {parsed_archives}/{len(tre_files)} TRE archives "
        f"({parsed_entries:,} TOC rows; {parsed_valid_rows:,} valid paths; "
        f"versions {versions or 'none'}; strides {strides or 'none'}; "
        f"compression {compressors or 'none'})."
    )

    if parsed_archives == 0:
        print("No TRE archive could be parsed. First 4 bytes/version diagnostics:")
        for tre_path in tre_files[:8]:
            try:
                with tre_path.open("rb") as f:
                    head = f.read(8)
                print(f"  {tre_path.name}: {head!r} / {head.hex(' ')}")
            except Exception as exc:
                print(f"  {tre_path.name}: {exc}")
    if sample_paths:
        print("Example internal paths found in the client:")
        for p in sample_paths:
            print(f"  {p}")

    for role, virtual_path in list(pending.items()):
        match = matches.get(role)
        if not match:
            continue

        tre_path, entry, matched_path = match
        destination = texture_root / Path(virtual_path).name
        if extract_from_tre(tre_path, entry, destination):
            found[role] = f"./assets/local-swg/texture/{destination.name}"
            pending.pop(role)
            suffix = "" if matched_path == virtual_path.lower() else f" ({matched_path})"
            print(f"TRE    {virtual_path}{suffix} <- {tre_path.name}")

    manifest = {
        "source": "local SWG client",
        "generatedAt": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "assets": found,
    }
    (output_root / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print()
    print(f"Imported {len(found)}/{len(TARGETS)} curated SWG textures.")
    if pending:
        print("Not found:")
        for virtual_path in pending.values():
            print(f"  {virtual_path}")

    print(f"Manifest: {output_root / 'manifest.json'}")
    return 0 if len(found) >= 3 else 1


if __name__ == "__main__":
    raise SystemExit(main())
