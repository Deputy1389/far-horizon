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
        return zlib.decompress(data)
    raise ValueError(f"Unsupported TRE compression type {kind}")


def read_tre_index(tre_path: Path):
    with tre_path.open("rb") as f:
        header = f.read(36)
        if len(header) != 36:
            return None

        magic, = struct.unpack_from("<I", header, 0)
        if magic != 0x54524545:
            return None

        record_count, toc_offset, toc_comp, toc_size, name_comp, name_size, name_uncompressed = struct.unpack_from(
            "<7I", header, 8
        )
        if not record_count or record_count > 2_000_000 or not toc_size or not name_size:
            return None

        f.seek(toc_offset)
        toc = inflate_maybe(f.read(toc_size), toc_comp)
        names = inflate_maybe(f.read(name_size), name_comp)

        stride = len(toc) // record_count
        if stride < 24:
            return None

        entries = {}
        for i in range(record_count):
            off = i * stride
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

            try:
                virtual_path = names[name_offset:end].decode("utf-8", errors="ignore").replace("\\", "/").lower()
            except Exception:
                continue

            entries[virtual_path] = {
                "uncompressed_size": uncompressed_size,
                "file_offset": file_offset,
                "compression": compression,
                "compressed_size": compressed_size,
            }

        return entries


def copy_loose(root: Path, virtual_path: str, destination: Path) -> bool:
    candidate = root.joinpath(*virtual_path.split("/"))
    if candidate.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(candidate.read_bytes())
        return True
    return False


def extract_from_tre(tre_path: Path, entry: dict, destination: Path) -> bool:
    try:
        with tre_path.open("rb") as f:
            f.seek(entry["file_offset"])
            packed = f.read(entry["compressed_size"])
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

    tre_files = sorted(source.rglob("*.tre"), key=lambda p: str(p).lower())
    print(f"Scanning {len(tre_files)} TRE archives for {len(pending)} texture(s)...")

    for tre_path in tre_files:
        if not pending:
            break

        try:
            index = read_tre_index(tre_path)
        except Exception:
            index = None
        if not index:
            continue

        for role, virtual_path in list(pending.items()):
            entry = index.get(virtual_path.lower())
            if not entry:
                continue

            destination = texture_root / Path(virtual_path).name
            if extract_from_tre(tre_path, entry, destination):
                found[role] = f"./assets/local-swg/texture/{destination.name}"
                pending.pop(role)
                print(f"TRE    {virtual_path} <- {tre_path.name}")

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
