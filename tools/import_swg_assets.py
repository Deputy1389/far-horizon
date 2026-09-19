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


def inflate_maybe(data: bytes, kind: int) -> bytes:
    if kind == 0:
        return data
    if kind == 2:
        try:
            return zlib.decompress(data)
        except zlib.error:
            return zlib.decompress(data, -zlib.MAX_WBITS)
    raise ValueError(f"Unsupported TRE compression type {kind}")


def read_tre_index(tre_path: Path):
    with tre_path.open("rb") as f:
        header = f.read(36)
        if len(header) != 36:
            return None

        # SWG TREE archives are written little-endian. Stock archives usually
        # contain the bytes b"EERT" (the LE dump of the 'TREE' tag).
        if header[:4] not in (b"EERT", b"TREE"):
            return None

        raw_version = header[4:8].decode("ascii", errors="ignore")
        version = raw_version if raw_version in {"0004", "0005", "0006", "5000", "6000"} else raw_version[::-1]

        record_count, toc_offset, toc_comp, toc_size, name_comp, name_size, name_uncompressed = struct.unpack_from(
            "<7I", header, 8
        )
        if not record_count or record_count > 2_000_000 or not toc_size or not name_size:
            return None

        # The client-side SearchTree implementation always materializes
        # exactly 24 bytes per TOC entry, including v0006 ("6000" on disk).
        # For an uncompressed TOC it reads record_count * 24 bytes and places
        # the name block immediately after that span. header.sizeOfTOC is only
        # the stored/compressed size used when the TOC itself is compressed.
        toc_uncompressed_size = record_count * 24

        f.seek(toc_offset)
        if toc_comp:
            toc_packed = f.read(toc_size)
            if len(toc_packed) != toc_size:
                return None
            toc = inflate_maybe(toc_packed, toc_comp)
            name_block_offset = toc_offset + toc_size
        else:
            toc = f.read(toc_uncompressed_size)
            if len(toc) != toc_uncompressed_size:
                return None
            name_block_offset = toc_offset + toc_uncompressed_size

        # Some community tools can recover archives with trailing TOC slack,
        # but the first 24 bytes per record are the actual SearchTree entry.
        if len(toc) < toc_uncompressed_size:
            return None
        toc = toc[:toc_uncompressed_size]

        f.seek(name_block_offset)
        if name_comp:
            name_packed = f.read(name_size)
            if len(name_packed) != name_size:
                return None
            names = inflate_maybe(name_packed, name_comp)
        else:
            # The stock client reads the uncompressed name block by its
            # uncompressed size, not necessarily header.sizeOfNameBlock.
            names = f.read(name_uncompressed)
            if len(names) != name_uncompressed:
                return None

        entries = {}
        for i in range(record_count):
            off = i * 24
            if off + 24 > len(toc):
                break

            _crc, uncompressed_size, file_offset, compression, compressed_size, name_offset = struct.unpack_from(
                "<6I", toc, off
            )
            if name_offset >= len(names):
                continue

            end = names.find(b"\x00", name_offset)
            if end == -1:
                end = len(names)

            virtual_path = names[name_offset:end].decode("utf-8", errors="ignore")
            virtual_path = virtual_path.replace("\\", "/").strip("/").lower()
            if not virtual_path:
                continue

            entries[virtual_path] = {
                "uncompressed_size": uncompressed_size,
                "file_offset": file_offset,
                "compression": compression,
                "compressed_size": compressed_size,
            }

        if not entries:
            return None

        return {
            "version": version,
            "entries": entries,
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
        data = inflate_maybe(packed, entry["compression"])
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
    versions: dict[str, int] = {}
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
        parsed_entries += len(entries)
        versions[archive["version"]] = versions.get(archive["version"], 0) + 1

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
        f"({parsed_entries:,} file records; versions {versions or 'none'})."
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
    elif not matches and sample_paths:
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
