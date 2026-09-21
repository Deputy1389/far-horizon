from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import zlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

try:
    from swg_twofish import decrypt_twofish_ecb
    from dds_png import DDSDecodeError, dds_to_png_file
except ImportError:  # pragma: no cover - supports importing as tools.import_swg_assets
    from tools.swg_twofish import decrypt_twofish_ecb
    from tools.dds_png import DDSDecodeError, dds_to_png_file


# This is the 128-bit key passed to Crypto::TwofishDecryptor by the Restoration
# client. It is used only to decode files from the user's local installation;
# no client payloads are stored in this repository.
RESTORATION_TWOFISH_KEY = bytes.fromhex("c73de04390a460725784c1e737ff67bb")


@dataclass(frozen=True)
class AssetEntry:
    virtual_path: str
    archive: Path
    metadata: dict[str, Any]

    @property
    def extension(self) -> str:
        return Path(self.virtual_path).suffix.lower()

    @property
    def archive_rank(self) -> int:
        return int(self.metadata.get("archive_rank", 0))


STATIC_ASSET_EXTENSIONS = {".msh", ".lod", ".pob", ".apt"}
MESH_KEYWORDS = (
    "tato",
    "tatt",
    "mos",
    "eisley",
    "starport",
    "moisture",
    "vapor",
    "jabba",
    "pipe",
    "cafe",
    "house",
    "industrial",
)

CHARACTER_MESH_RULES: dict[str, dict[str, Any]] = {
    "stormtrooper": {
        "include": {"stormtrooper": 120, "trooper": 36, "statue": 70, "frn": 24, "l0": 12},
        "exclude": ("helmet", "toy", "weapon", "gun", "pile", "painting", "decor", "hook", "badge"),
        "require_any": ("stormtrooper", "trooper"),
    },
    "firstPersonHands": {
        "include": {"hum_m_hands": 180, "hands": 80, "hum_m": 40, "l0": 20},
        "exclude": ("rod_", "wke_", "ith_", "gloves", "frn", "statue"),
        "require_any": ("hands",),
    },
}


WEAPON_MESH_RULES: dict[str, dict[str, Any]] = {
    "blasterRifle": {
        "include": {"rifle": 100, "blaster": 70, "weapon": 25, "weap": 25, "wpn": 25, "stormtrooper": 20},
        "exclude": ("scope", "barrel", "stock", "muzzle", "projectile", "ammo", "frn", "furniture", "statue", "rack", "display", "decal", "icon"),
        "require_any": ("rifle",),
    },
    "blasterPistol": {
        "include": {"pistol": 100, "blaster": 70, "weapon": 25, "weap": 25, "wpn": 25},
        "exclude": ("scope", "barrel", "grip", "projectile", "ammo", "frn", "furniture", "statue", "rack", "display", "decal", "icon"),
        "require_any": ("pistol",),
    },
}


AUDIO_TARGETS: dict[str, tuple[str, ...]] = {
    "blasterPistol": (
        "sample/wep_blaster_fire_2.wav",
        "sample/wep_blaster_rifle_02.wav",
    ),
    "blasterRifle": (
        "sample/wep_blaster_rifle_02.wav",
        "sample/wep_blaster_fire_2.wav",
    ),
    "speederLoop": (
        "sample/veh_flashspeeder_run_lp.wav",
    ),
    "footstepSand1": (
        "sample/fs_out_sand_crunch_01.wav",
    ),
    "footstepSand2": (
        "sample/fs_out_sand_crunch_02.wav",
    ),
    "footstepSand3": (
        "sample/fs_out_sand_crunch_03.wav",
    ),
    "footstepSand4": (
        "sample/fs_out_sand_crunch_04.wav",
    ),
    "tatooineAmbience": (
        "sample/amb_tatooine_mos_eisley_lp.wav",
        "sample/amb_tatooine_anchorhead_lp.wav",
    ),
}


# Rules deliberately use semantic fragments instead of a list of guessed full
# filenames. The importer ranks the complete local path inventory, so a client
# patch can rename or add a more appropriate material without code changes.
ROLE_RULES: dict[str, dict[str, Any]] = {
    "sand": {
        "include": {"tatt": 40, "sand": 32, "bumpy": 24, "desert": 12, "dune": 10, "terrain": 6},
        "preferred": ["texture/tatt_sand_bumpy_a1", "texture/tatt_sand_bumpy", "texture/generic_tatooine_floor"],
        "exclude": ["_n", "normal", "_spec", "spec", "_cn", "_dirt", "detail", "mask"],
        "require_any": ["sand", "desert", "dune"],
    },
    "sandNormal": {
        "include": {"tatt": 40, "sand": 32, "bumpy": 24, "normal": 18, "_n": 18, "desert": 8},
        "preferred": ["texture/tatt_sand_bumpy_a1_n", "texture/tatt_sand_bumpy_n", "sand_bumpy_n"],
        "exclude": ["_spec", "spec", "_cn", "_dirt", "detail", "mask"],
        "require_any": ["_n", "normal"],
    },
    "wall": {
        "include": {"tatt": 34, "wall": 34, "stucco": 24, "stco": 24, "tato": 10, "desert": 5},
        "preferred": ["texture/tatt_stco_player_wall", "texture/tato_bank_wall_base", "texture/intr_cptl_tatt_wall_a1"],
        "exclude": ["trim", "_n", "normal", "_spec", "spec", "_dirt", "detail", "deco", "floor"],
        "require_any": ["wall", "stucco", "stco"],
    },
    "wallDetail": {
        "include": {"tatt": 30, "wall": 30, "stco": 25, "detail": 24, "detl": 24, "dirt": 8, "deco": 6},
        "preferred": ["texture/tatt_stco_player_wall_detlb", "texture/tatt_stco_player_wall_detla", "wall_detail"],
        "exclude": ["_n", "normal", "_spec", "spec", "mask", "floor"],
        "require_any": ["detail", "detl", "dirt", "deco"],
    },
    "floor": {
        "include": {"tatt": 28, "floor": 36, "tile": 24, "tato": 10, "intr": 8, "stucco": 4},
        "preferred": ["texture/tatt_stco_player_floor_c", "texture/tatt_stco_player_floor", "texture/tato_floor_tilea", "texture/intr_cptl_tatt_floor"],
        "exclude": ["_n", "normal", "_spec", "spec", "detail", "_dirt", "mask"],
        "require_any": ["floor", "tile"],
    },
    "capitalWall": {
        "include": {"intr": 16, "cptl": 34, "tatt": 28, "wall": 30, "trim": 18, "stucco": 16, "tato": 8},
        "preferred": ["texture/intr_cptl_tatt_wall_trim", "texture/intr_cptl_tatt_wall_a1", "texture/tato_bank_wall_base"],
        "exclude": ["_n", "normal", "_spec", "spec", "_dirt", "detail", "deco", "floor"],
        "require_any": ["wall", "trim", "stucco"],
    },
    "capitalStair": {
        "include": {"intr": 18, "cptl": 30, "tatt": 28, "stair": 48, "step": 38, "floor": 6},
        "preferred": ["texture/intr_cptl_tatt_stair", "texture/intr_cptl_tatt_floor"],
        "exclude": ["_n", "normal", "_spec", "spec", "detail", "mask"],
        "require_any": ["stair", "step"],
    },
    "concrete": {
        "include": {"concrete": 44, "impl": 24, "cncr": 22, "tato": 14, "spaceport": 12, "slab": 10, "industrial": 8},
        "preferred": ["texture/impl_concrete_a", "texture/tato_concretea", "texture/spaceport_concrete"],
        "exclude": ["detail", "_n", "normal", "_spec", "spec", "rubble", "_dirt", "mask"],
        "require_any": ["concrete", "cncr", "spaceport", "impl"],
    },
    "concreteDetail": {
        "include": {"concrete": 34, "detail": 42, "impl": 24, "rubble": 20, "dirt": 12, "cncr": 12},
        "preferred": ["texture/impl_concrete_detail_a", "texture/impl_concrete_a_rubble", "texture/spaceport_concrete_dirt"],
        "exclude": ["_n", "normal", "_spec", "spec", "mask"],
        "require_any": ["detail", "rubble", "dirt", "concrete"],
    },
    "metal": {
        "include": {"metal": 38, "metl": 38, "ins": 24, "industrial": 18, "impl": 8, "gray": 8, "pipe": 6},
        "preferred": ["texture/ins_all_metl_gray", "texture/all_metal_streaked", "texture/all_metl_impl_gate", "texture/tato_fallen_star_metal_plates"],
        "exclude": ["vents", "vent", "_n", "normal", "_spec", "spec", "detail", "rust", "dirt"],
        "require_any": ["metal", "metl", "ins", "industrial"],
    },
    "metalVents": {
        "include": {"metal": 32, "metl": 32, "vents": 38, "vent": 38, "ins": 22, "grate": 24, "panel": 18, "industrial": 14},
        "preferred": ["texture/ins_all_metl_gray_vents_a1", "texture/tatt_metl_floor_roundgrate", "texture/tatt_ming_hydro_vap_metalpanel"],
        "exclude": ["_n", "normal", "_spec", "spec", "mask"],
        "require_any": ["vents", "vent", "grate", "panel", "metal", "metl"],
    },
    "road": {
        "include": {"road": 46, "rock": 18, "tato": 16, "concrete": 16, "asphalt": 18, "sand": 6, "slab": 6},
        "preferred": ["texture/rock_tato_road", "texture/tato_concretea", "texture/spaceport_concrete"],
        "exclude": ["_n", "normal", "_spec", "spec", "detail", "_dirt", "mask"],
        "require_any": ["road", "asphalt", "concrete", "slab"],
    },
    "roadDetail": {
        "include": {"road": 38, "detail": 32, "rock": 20, "tato": 10, "dirt": 8, "rubble": 8},
        "preferred": ["texture/rock_tato_road_a1", "texture/spaceport_concrete_dirt", "texture/tato_concrete_capitol_dirt"],
        "exclude": ["_n", "normal", "_spec", "spec", "mask"],
        "require_any": ["road", "detail", "dirt", "rubble"],
    },
    "pad": {
        "include": {"spaceport": 52, "starport": 48, "landing": 44, "pad": 44, "concrete": 22, "tato": 8, "industrial": 6},
        "preferred": ["texture/spaceport_concrete", "texture/spaceport_concrete_dirt", "texture/rock_tato_road"],
        "exclude": ["_n", "normal", "_spec", "spec", "detail", "mask"],
        "require_any": ["spaceport", "starport", "landing", "pad"],
    },
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

    seen: set[str] = set()
    found: list[Path] = []
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
    attempts: list[bytes] = []
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

        f.seek(toc_offset)
        toc_on_disk = f.read(toc_size)
        if len(toc_on_disk) != toc_size:
            return None

        decoded_toc = decode_toc(toc_on_disk, toc_comp, record_count)
        if not decoded_toc:
            return None
        toc_blob, stride = decoded_toc

        name_block_offset = toc_offset + toc_size
        f.seek(name_block_offset)
        name_read_size = name_size if name_comp != 0 else name_uncompressed
        name_on_disk = f.read(name_read_size)
        if len(name_on_disk) != name_read_size:
            return None

        names = decode_name_block(name_on_disk, name_comp, name_uncompressed)
        if names is None:
            return None

        entries: dict[str, dict[str, Any]] = {}
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
            if not virtual_path or len(virtual_path) > 512:
                continue
            if any(ord(ch) < 32 for ch in virtual_path):
                continue

            entries[virtual_path] = {
                "uncompressed_size": uncompressed_size,
                "file_offset": file_offset,
                "compression": compression,
                "compressed_size": compressed_size,
                "archive": tre_path,
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


def inventory_from_archives(tre_files: Iterable[Path]) -> tuple[list[AssetEntry], dict[str, Any]]:
    tre_files = list(tre_files)
    inventory: list[AssetEntry] = []
    versions: dict[str, int] = {}
    strides: dict[int, int] = {}
    compressors: dict[str, int] = {}
    errors: list[dict[str, str]] = []
    parsed_archives = 0
    parsed_rows = 0
    valid_rows = 0

    for archive_rank, tre_path in enumerate(tre_files):
        try:
            archive = read_tre_index(tre_path)
        except Exception as exc:  # pragma: no cover - protects a full client scan
            archive = None
            errors.append({"archive": tre_path.name, "error": str(exc)})

        if not archive:
            continue

        parsed_archives += 1
        parsed_rows += int(archive.get("record_count", 0))
        valid_rows += int(archive.get("valid_rows", 0))
        versions[archive["version"]] = versions.get(archive["version"], 0) + 1
        strides[archive["stride"]] = strides.get(archive["stride"], 0) + 1
        comp_key = f"toc{archive.get('toc_compressor', '?')}/name{archive.get('name_compressor', '?')}"
        compressors[comp_key] = compressors.get(comp_key, 0) + 1

        for virtual_path, metadata in archive["entries"].items():
            inventory.append(AssetEntry(virtual_path, tre_path, {**metadata, "archive_rank": archive_rank}))

    stats = {
        "archiveCount": len(tre_files),
        "parsedArchives": parsed_archives,
        "parsedRows": parsed_rows,
        "validRows": valid_rows,
        "uniquePaths": len({entry.virtual_path for entry in inventory}),
        "versions": versions,
        "strides": strides,
        "compression": compressors,
        "errors": errors,
    }
    return inventory, stats


def search_entries(entries: Iterable[AssetEntry], terms: Iterable[str], extension: str | None = None) -> list[AssetEntry]:
    normalized_terms = [term.lower().replace("\\", "/") for term in terms if term]
    normalized_extension = extension.lower() if extension else None
    if normalized_extension and not normalized_extension.startswith("."):
        normalized_extension = f".{normalized_extension}"

    aliases = {
        "tato": ("tato", "tatt"),
        "tatooine": ("tatooine", "tato", "tatt"),
        "mos": ("mos", "mse"),
        "eisley": ("eisley", "mse"),
        "industrial": ("industrial", "impl", "ins"),
    }

    def matches(path: str, term: str) -> bool:
        return any(alias in path for alias in aliases.get(term, (term,)))

    result = [
        entry
        for entry in entries
        if all(matches(entry.virtual_path.lower(), term) for term in normalized_terms)
        and (normalized_extension is None or entry.extension == normalized_extension)
    ]
    return sorted(result, key=lambda entry: (entry.virtual_path, -entry.archive_rank, str(entry.archive).lower()))


def _role_score(entry: AssetEntry, role: str) -> int | None:
    rule = ROLE_RULES[role]
    path = entry.virtual_path.lower()
    if entry.extension != ".dds":
        return None
    if any(fragment in path for fragment in rule.get("exclude", [])):
        return None
    required = rule.get("require_any", [])
    if required and not any(fragment in path for fragment in required):
        return None

    score = sum(weight for fragment, weight in rule.get("include", {}).items() if fragment in path)
    if score <= 0:
        return None
    for index, fragment in enumerate(rule.get("preferred", [])):
        if fragment in path:
            score += 500 - index * 25
            break
    if path.startswith("texture/"):
        score += 5
    return score


def select_asset(entries: Iterable[AssetEntry], role: str) -> AssetEntry | None:
    if role not in ROLE_RULES:
        raise KeyError(f"Unknown asset role: {role}")

    ranked = [(score, entry) for entry in entries if (score := _role_score(entry, role)) is not None]
    if not ranked:
        return None
    ranked.sort(key=lambda item: (-item[0], item[1].virtual_path, -item[1].archive_rank, str(item[1].archive).lower()))
    return ranked[0][1]


def ranked_assets(entries: Iterable[AssetEntry], role: str, limit: int = 10) -> list[tuple[int, AssetEntry]]:
    ranked = [(score, entry) for entry in entries if (score := _role_score(entry, role)) is not None]
    ranked.sort(key=lambda item: (-item[0], item[1].virtual_path, -item[1].archive_rank, str(item[1].archive).lower()))
    return ranked[:limit]


def static_asset_candidates(entries: Iterable[AssetEntry], extension: str | None = None) -> list[AssetEntry]:
    normalized_extension = extension.lower() if extension else None
    if normalized_extension and not normalized_extension.startswith("."):
        normalized_extension = f".{normalized_extension}"

    candidates = [
        entry
        for entry in entries
        if entry.extension in STATIC_ASSET_EXTENSIONS
        and (normalized_extension is None or entry.extension == normalized_extension)
        and any(keyword in entry.virtual_path for keyword in MESH_KEYWORDS)
    ]

    def sort_key(entry: AssetEntry) -> tuple[int, str, int, str]:
        priority = 0 if any(term in entry.virtual_path for term in ("moisture", "vapor", "starport", "jabba", "pipe", "cafe", "house")) else 1
        return priority, entry.virtual_path, -entry.archive_rank, str(entry.archive).lower()

    return sorted(candidates, key=sort_key)


def _character_mesh_score(entry: AssetEntry, role: str) -> int | None:
    rule = CHARACTER_MESH_RULES.get(role)
    if rule is None or entry.extension != ".msh":
        return None
    path = entry.virtual_path.lower()
    if any(fragment in path for fragment in rule["exclude"]):
        return None
    if not any(fragment in path for fragment in rule["require_any"]):
        return None
    score = sum(weight for fragment, weight in rule["include"].items() if fragment in path)
    if not path.startswith("appearance/mesh/"):
        score -= 15
    return score if score > 0 else None


def select_character_mesh(entries: Iterable[AssetEntry], role: str) -> AssetEntry | None:
    ranked = [
        (score, entry)
        for entry in entries
        if (score := _character_mesh_score(entry, role)) is not None
    ]
    ranked.sort(key=lambda item: (-item[0], item[1].virtual_path, -item[1].archive_rank, str(item[1].archive).lower()))
    return ranked[0][1] if ranked else None


def ranked_character_meshes(entries: Iterable[AssetEntry], role: str, limit: int = 20) -> list[tuple[int, AssetEntry]]:
    ranked = [
        (score, entry)
        for entry in entries
        if (score := _character_mesh_score(entry, role)) is not None
    ]
    ranked.sort(key=lambda item: (-item[0], item[1].virtual_path, -item[1].archive_rank, str(item[1].archive).lower()))
    return ranked[:limit]


def select_weapon_mesh(entries: Iterable[AssetEntry], role: str) -> AssetEntry | None:
    rule = WEAPON_MESH_RULES.get(role)
    if rule is None:
        return None
    ranked: list[tuple[int, AssetEntry]] = []
    for entry in entries:
        if entry.extension != ".msh":
            continue
        path = entry.virtual_path.lower()
        if not path.startswith("appearance/mesh/"):
            continue
        if any(fragment in path for fragment in rule["exclude"]):
            continue
        if not any(fragment in path for fragment in rule["require_any"]):
            continue
        score = sum(weight for fragment, weight in rule["include"].items() if fragment in path)
        if "l0" in path or "_l0" in path:
            score += 18
        if path.count("/") <= 3:
            score += 5
        ranked.append((score, entry))
    ranked.sort(key=lambda item: (-item[0], -item[1].archive_rank, item[1].virtual_path))
    return ranked[0][1] if ranked else None


def build_manifest_asset(entry: AssetEntry, url: str) -> dict[str, Any]:
    return {
        "url": url,
        "archive": entry.archive.name,
        "archivePath": str(entry.archive),
        "archiveRank": entry.archive_rank,
        "virtualPath": entry.virtual_path,
        "kind": entry.extension.lstrip(".") or "binary",
        "uncompressedSize": int(entry.metadata.get("uncompressed_size", 0)),
        "compression": int(entry.metadata.get("compression", 0)),
    }


def copy_loose(root: Path, virtual_path: str, destination: Path) -> Path | None:
    candidate = root.joinpath(*virtual_path.split("/"))
    if candidate.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(candidate.read_bytes())
        return candidate

    normalized = virtual_path.replace("\\", "/").strip("/").lower()
    matches: list[Path] = []
    for loose in sorted(root.rglob("*"), key=lambda path: str(path).lower()):
        if not loose.is_file():
            continue
        try:
            relative = loose.relative_to(root).as_posix().lower()
        except ValueError:
            continue
        if relative == normalized or relative.endswith(f"/{normalized}"):
            matches.append(loose)
    if not matches:
        return None

    # Nested patch folders are allowed, but basename-only matches are not. If
    # several exact virtual-path overrides exist, lexical order gives a stable
    # local choice and the manifest records the chosen source path.
    source = matches[-1]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(source.read_bytes())
    return source


def is_valid_dds_payload(data: bytes) -> bool:
    if len(data) < 128 or data[:4] != b"DDS ":
        return False
    header_size, height, width = struct.unpack_from("<III", data, 4)
    return header_size == 124 and width > 0 and height > 0


def is_valid_dds_file(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            return is_valid_dds_payload(stream.read(128))
    except OSError:
        return False


DDSD_LINEARSIZE = 0x00080000

_DDS_BLOCK_BYTES: dict[bytes, int] = {
    b"DXT1": 8,
    b"ATI1": 8,
    b"BC4U": 8,
    b"BC4S": 8,
    b"DXT2": 16,
    b"DXT3": 16,
    b"DXT4": 16,
    b"DXT5": 16,
    b"ATI2": 16,
    b"BC5U": 16,
    b"BC5S": 16,
}


def normalize_dds_payload_for_godot(data: bytes) -> tuple[bytes, bool]:
    """Repair legacy SWG DDS linear-size headers that modern Godot rejects.

    SWG-era DDS writers commonly stored a whole mip-chain byte count in
    dwPitchOrLinearSize. Modern Godot validates that field against the top-level
    block-compressed image size. The pixel payload is already valid, so changing
    this one header field preserves the original texture while making it standards
    compliant enough for Godot's DDS importer.
    """
    if not is_valid_dds_payload(data):
        return data, False

    flags = struct.unpack_from("<I", data, 8)[0]
    if not (flags & DDSD_LINEARSIZE):
        return data, False

    height, width, declared_size = struct.unpack_from("<III", data, 12)
    fourcc = data[84:88]
    block_bytes = _DDS_BLOCK_BYTES.get(fourcc)
    if block_bytes is None:
        return data, False

    expected_size = max(1, (width + 3) // 4) * max(1, (height + 3) // 4) * block_bytes
    if declared_size == expected_size:
        return data, False

    patched = bytearray(data)
    struct.pack_into("<I", patched, 20, expected_size)
    return bytes(patched), True


def normalize_dds_file_for_godot(path: Path) -> bool:
    try:
        data = path.read_bytes()
    except OSError:
        return False
    normalized, changed = normalize_dds_payload_for_godot(data)
    if changed:
        path.write_bytes(normalized)
    return changed


def is_valid_wav_file(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            header = stream.read(12)
        return len(header) == 12 and header[:4] == b"RIFF" and header[8:12] == b"WAVE"
    except OSError:
        return False


def _known_plain_magic(data: bytes) -> bool:
    return data.startswith((b"DDS ", b"RIFF", b"FORM", b"MIF", b"LATA", b"LAT ", b"SOTA"))


def decode_tre_entry(tre_path: Path, entry: dict[str, Any]) -> bytes:
    """Read one Restoration payload, decrypting its padded Twofish stream."""
    compressed = bool(entry.get("compression"))
    expected_size = int(entry.get("uncompressed_size", 0))
    stored_size = int(entry.get("compressed_size" if compressed else "uncompressed_size", 0))
    if stored_size <= 0:
        raise ValueError("TRE entry has no payload size")

    padded_size = (stored_size + 15) & ~15
    with tre_path.open("rb") as f:
        f.seek(int(entry["file_offset"]))
        packed = f.read(padded_size)
    if len(packed) < stored_size:
        raise ValueError(f"short payload: expected {stored_size}, got {len(packed)}")

    # Loose files and older public TREs can be plain. Prefer this cheap path,
    # then use the encrypted Restoration path when the bytes are not a stream.
    if compressed:
        try:
            decoded = _zlib_decompress(packed[:stored_size])
            if not expected_size or len(decoded) >= expected_size:
                return decoded[:expected_size] if expected_size else decoded
        except Exception:
            pass
    elif _known_plain_magic(packed[:16]):
        return packed[:expected_size] if expected_size else packed[:stored_size]

    decryptable_size = len(packed) - (len(packed) % 16)
    if decryptable_size < 16:
        raise ValueError("encrypted payload is shorter than one Twofish block")
    decrypted = decrypt_twofish_ecb(packed[:decryptable_size], RESTORATION_TWOFISH_KEY)

    if compressed:
        decoded = _zlib_decompress(decrypted)
    else:
        decoded = decrypted

    if expected_size and len(decoded) < expected_size:
        raise ValueError(f"decoded payload is short: expected {expected_size}, got {len(decoded)}")
    return decoded[:expected_size] if expected_size else decoded


def extract_from_tre(tre_path: Path, entry: dict[str, Any], destination: Path) -> tuple[bool, str | None]:
    try:
        data = decode_tre_entry(tre_path, entry)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        return True, None
    except Exception as exc:
        return False, str(exc)


def _print_search_results(entries: list[AssetEntry], terms: list[str], extension: str | None, limit: int) -> None:
    matches = search_entries(entries, terms, extension)
    print(f"Search {' '.join(terms)!r}: {len(matches):,} matching inventory rows")
    shown: set[tuple[str, str]] = set()
    for entry in matches:
        identity = (str(entry.archive).lower(), entry.virtual_path)
        if identity in shown:
            continue
        shown.add(identity)
        print(
            f"  {entry.archive.name} :: {entry.virtual_path} "
            f"[{entry.extension or 'no extension'}, {entry.metadata.get('uncompressed_size', 0):,} bytes, "
            f"compression={entry.metadata.get('compression', 0)}]"
        )
        if len(shown) >= limit:
            break


def _mesh_report(entries: list[AssetEntry], limit: int, extension: str | None = None) -> None:
    print("SWG static-environment candidates (catalog only; no copyrighted files are written):")
    candidates = static_asset_candidates(entries, extension)
    for entry in candidates[:limit]:
        print(f"  {entry.archive.name} :: {entry.virtual_path}")
    print(f"  ... {len(candidates):,} matching static-environment candidates in the parsed inventory")


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, default=str) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Discover, decrypt, and import a curated SWG Restoration asset set from a local client install."
    )
    parser.add_argument("--source", "-s", help="Path to your SWG Restoration client folder.")
    parser.add_argument("--search", nargs="+", help="List virtual paths containing every supplied keyword.")
    parser.add_argument("--extension", help="Restrict --search/--mesh-report output, for example .dds or .msh.")
    parser.add_argument("--limit", type=int, default=40, help="Maximum search/report rows to print (default: 40).")
    parser.add_argument("--mesh-report", action="store_true", help="List reusable static-environment candidates and exit.")
    args = parser.parse_args()

    roots = candidate_roots(args.source)
    if not roots:
        print("Could not find an SWG Restoration install automatically.", file=sys.stderr)
        print(r'Run: py tools\import_swg_assets.py --source "C:\path\to\SWG Restoration"', file=sys.stderr)
        return 2

    source = roots[0]
    print(f"Using SWG client: {source}")
    tre_files = sorted(
        [path for path in source.rglob("*") if path.is_file() and path.suffix.lower() == ".tre"],
        key=lambda path: str(path).lower(),
    )
    print(f"Scanning {len(tre_files)} TRE archives for the local SWG path inventory...")
    inventory, stats = inventory_from_archives(tre_files)
    print(
        f"Parsed {stats['parsedArchives']}/{stats['archiveCount']} TRE archives "
        f"({stats['parsedRows']:,} TOC rows; {stats['validRows']:,} valid paths; "
        f"{stats['uniquePaths']:,} unique paths; versions {stats['versions'] or 'none'}; "
        f"strides {stats['strides'] or 'none'}; compression {stats['compression'] or 'none'})."
    )
    if stats["errors"]:
        for error in stats["errors"][:8]:
            print(f"  parse warning: {error['archive']}: {error['error']}")

    if args.search:
        _print_search_results(inventory, args.search, args.extension, max(1, args.limit))
        return 0
    if args.mesh_report:
        _mesh_report(inventory, max(1, args.limit), args.extension)
        return 0

    project_root = Path(__file__).resolve().parents[1]
    output_root = project_root / "assets" / "local-swg"
    texture_root = output_root / "texture"
    texture_root.mkdir(parents=True, exist_ok=True)
    # Keep original DDS files for the browser pipeline, but do not make Godot
    # try to import them. Some SWG-era DDS variants are accepted by the old
    # client/Three.js but rejected by current Godot DDS validation.
    (texture_root / ".gdignore").write_text("", encoding="utf-8")
    godot_texture_root = output_root / "godot" / "texture"
    godot_texture_root.mkdir(parents=True, exist_ok=True)

    path_index: dict[str, AssetEntry] = {}
    for entry in inventory:
        key = entry.virtual_path.lower()
        previous = path_index.get(key)
        if previous is None or entry.archive_rank > previous.archive_rank:
            path_index[key] = entry

    audio_root = output_root / "audio"
    audio_root.mkdir(parents=True, exist_ok=True)
    audio_assets: dict[str, dict[str, Any]] = {}
    audio_failures: dict[str, str] = {}
    for role, candidates in AUDIO_TARGETS.items():
        selected_audio: AssetEntry | None = None
        for candidate in candidates:
            selected_audio = path_index.get(candidate.lower())
            if selected_audio is not None:
                break
        if selected_audio is None:
            audio_failures[role] = "no known SWG WAV candidate found"
            print(f"AUDIO  miss {role}: {audio_failures[role]}")
            continue

        destination = audio_root / f"{role}.wav"
        loose_path = copy_loose(source, selected_audio.virtual_path, destination)
        source_kind = "loose"
        if loose_path is None:
            source_kind = "TRE"
            ok, error = extract_from_tre(selected_audio.archive, selected_audio.metadata, destination)
            if not ok:
                audio_failures[role] = error or "TRE extraction failed"
                destination.unlink(missing_ok=True)
                print(f"AUDIO  miss {role}: {audio_failures[role]}")
                continue
        if not is_valid_wav_file(destination):
            audio_failures[role] = "decoded sample was not a standard RIFF/WAVE payload"
            destination.unlink(missing_ok=True)
            print(f"AUDIO  miss {role}: {audio_failures[role]}")
            continue

        url = f"./assets/local-swg/audio/{destination.name}"
        descriptor = build_manifest_asset(selected_audio, url)
        descriptor["sourceKind"] = source_kind
        if loose_path is not None:
            descriptor["sourcePath"] = str(loose_path.relative_to(source).as_posix())
        audio_assets[role] = descriptor
        print(f"AUDIO  {role:<14} {selected_audio.archive.name} :: {selected_audio.virtual_path} [{source_kind}]")

    manifest_assets: dict[str, dict[str, Any]] = {}
    selections: dict[str, dict[str, Any]] = {}
    failures: dict[str, str] = {}
    imported = 0

    for role in ROLE_RULES:
        candidates = ranked_assets(inventory, role, limit=20)
        if not candidates:
            failures[role] = "no ranked DDS candidate"
            print(f"MISS   {role}: no matching DDS candidate")
            continue

        imported_role = False
        for score, entry in candidates:
            destination_name = f"{role}_{Path(entry.virtual_path).stem}.dds"
            destination = texture_root / destination_name
            source_kind = "loose"
            error: str | None = None
            loose_path: Path | None = None

            loose_path = copy_loose(source, entry.virtual_path, destination)
            if loose_path is None:
                source_kind = "TRE"
                ok, error = extract_from_tre(entry.archive, entry.metadata, destination)
                if not ok:
                    try:
                        destination.unlink(missing_ok=True)
                    except OSError:
                        pass
                    continue
            else:
                ok = True

            if ok:
                normalize_dds_file_for_godot(destination)

            if ok and not is_valid_dds_file(destination):
                error = "decoded candidate did not have a valid DDS header"
                try:
                    destination.unlink(missing_ok=True)
                except OSError:
                    pass
                continue

            if not ok:
                continue

            url = f"./assets/local-swg/texture/{destination.name}"
            godot_url = ""
            try:
                godot_destination = godot_texture_root / f"{role}.png"
                dds_to_png_file(destination, godot_destination)
                godot_url = f"./assets/local-swg/godot/texture/{godot_destination.name}"
            except (OSError, DDSDecodeError, ValueError) as exc:
                print(f"WARN   {role}: could not build Godot PNG fallback: {exc}")

            manifest_assets[role] = build_manifest_asset(entry, url)
            if godot_url:
                manifest_assets[role]["godotUrl"] = godot_url
            manifest_assets[role]["sourceKind"] = source_kind
            if loose_path is not None:
                manifest_assets[role]["sourcePath"] = str(loose_path.relative_to(source).as_posix())
            selections[role] = {
                "score": score,
                "archive": entry.archive.name,
                "archivePath": str(entry.archive),
                "archiveRank": entry.archive_rank,
                "virtualPath": entry.virtual_path,
                "url": url,
            }
            imported += 1
            print(f"SELECT {role:<14} score={score:<4} {entry.archive.name} :: {entry.virtual_path} [{source_kind}]")
            imported_role = True
            break

        if not imported_role:
            failures[role] = error or "all ranked candidates failed to decode"
            print(f"MISS   {role}: {failures[role]}")

    mesh_candidates_all = [
        {
            "archive": entry.archive.name,
            "archivePath": str(entry.archive),
            "archiveRank": entry.archive_rank,
            "virtualPath": entry.virtual_path,
            "extension": entry.extension,
            "uncompressedSize": int(entry.metadata.get("uncompressed_size", 0)),
        }
        for entry in static_asset_candidates(inventory)
    ]
    mesh_candidates = mesh_candidates_all[:500]

    character_candidates_all = [
        {
            "role": role,
            "score": score,
            "archive": entry.archive.name,
            "archivePath": str(entry.archive),
            "archiveRank": entry.archive_rank,
            "virtualPath": entry.virtual_path,
            "extension": entry.extension,
            "uncompressedSize": int(entry.metadata.get("uncompressed_size", 0)),
        }
        for role in CHARACTER_MESH_RULES
        for score, entry in ranked_character_meshes(inventory, role, limit=100)
    ]

    mesh_proof: dict[str, Any] | None = None
    try:
        from convert_swg_mesh import convert_from_inventory

        mesh_root = output_root / "mesh"
        mesh_gltf = mesh_root / "ins_all_min_moisture_s01_u0_l0.gltf"
        mesh_bin = mesh_gltf.with_suffix(".bin")
        mesh_entry, mesh_summary = convert_from_inventory(inventory, mesh_gltf, mesh_bin)
        mesh_proof = {
            "url": f"./assets/local-swg/mesh/{mesh_gltf.name}",
            "archive": mesh_entry.archive.name,
            "archivePath": str(mesh_entry.archive),
            "archiveRank": mesh_entry.archive_rank,
            "virtualPath": mesh_entry.virtual_path,
            "bin": f"./assets/local-swg/mesh/{mesh_bin.name}",
            **mesh_summary,
        }
        print(
            f"MESH   proof {mesh_entry.archive.name} :: {mesh_entry.virtual_path} "
            f"({mesh_summary['submeshes']} submeshes, {mesh_summary['vertices']:,} vertices)"
        )
    except Exception as exc:
        print(f"MESH   proof unavailable: {exc}")

    weapons: dict[str, dict[str, Any]] = {}
    weapon_failures: dict[str, str] = {}
    try:
        from convert_swg_mesh import (
            convert_from_inventory as convert_weapon_from_inventory,
            extract_shader_texture_paths,
            parse_static_mesh,
        )

        weapon_root = output_root / "weapon"
        for role in WEAPON_MESH_RULES:
            weapon_entry = select_weapon_mesh(inventory, role)
            if weapon_entry is None:
                weapon_failures[role] = "no suitable SWG weapon .msh candidate found"
                print(f"WEAPON miss {role}: {weapon_failures[role]}")
                continue

            weapon_gltf = weapon_root / role / f"{role}.gltf"
            weapon_bin = weapon_gltf.with_suffix(".bin")
            converted_entry, weapon_summary = convert_weapon_from_inventory(
                inventory,
                weapon_gltf,
                weapon_bin,
                preferred_virtual_path=weapon_entry.virtual_path,
            )

            source_submeshes = parse_static_mesh(
                decode_tre_entry(converted_entry.archive, converted_entry.metadata)
            )
            shader_bindings: dict[str, list[str]] = {}
            shader_texture_paths: set[str] = set()
            for submesh in source_submeshes:
                shader_entry = path_index.get(submesh.shader.lower())
                if shader_entry is None:
                    shader_bindings[submesh.shader] = []
                    continue
                shader_paths = extract_shader_texture_paths(
                    decode_tre_entry(shader_entry.archive, shader_entry.metadata)
                )
                shader_bindings[submesh.shader] = shader_paths
                shader_texture_paths.update(shader_paths)

            weapon_texture_root = weapon_root / role / "texture"
            weapon_texture_root.mkdir(parents=True, exist_ok=True)
            (weapon_texture_root / ".gdignore").write_text("", encoding="utf-8")
            weapon_godot_texture_root = output_root / "godot" / "weapon" / role
            weapon_godot_texture_root.mkdir(parents=True, exist_ok=True)
            weapon_textures: dict[str, dict[str, Any]] = {}
            failed_texture_paths: dict[str, str] = {}
            for shader_texture_path in sorted(shader_texture_paths):
                texture_entry = path_index.get(shader_texture_path.lower())
                if texture_entry is None:
                    failed_texture_paths[shader_texture_path] = "shader DDS path not present in inventory"
                    continue
                destination = weapon_texture_root / Path(shader_texture_path).name
                loose_path = copy_loose(source, texture_entry.virtual_path, destination)
                source_kind = "loose"
                if loose_path is None:
                    source_kind = "TRE"
                    ok, error = extract_from_tre(texture_entry.archive, texture_entry.metadata, destination)
                    if not ok:
                        failed_texture_paths[shader_texture_path] = error or "TRE extraction failed"
                        destination.unlink(missing_ok=True)
                        continue
                normalize_dds_file_for_godot(destination)
                if not is_valid_dds_file(destination):
                    failed_texture_paths[shader_texture_path] = "decoded shader reference did not have a valid DDS header"
                    destination.unlink(missing_ok=True)
                    continue

                godot_url = ""
                try:
                    godot_destination = weapon_godot_texture_root / f"{Path(shader_texture_path).stem}.png"
                    dds_to_png_file(destination, godot_destination)
                    godot_url = f"./assets/local-swg/godot/weapon/{role}/{godot_destination.name}"
                except (OSError, DDSDecodeError, ValueError) as exc:
                    failed_texture_paths[shader_texture_path] = f"Godot PNG conversion failed: {exc}"

                descriptor = build_manifest_asset(
                    texture_entry,
                    f"./assets/local-swg/weapon/{role}/texture/{destination.name}",
                )
                if godot_url:
                    descriptor["godotUrl"] = godot_url
                descriptor["sourceKind"] = source_kind
                weapon_textures[shader_texture_path] = descriptor

            weapons[role] = {
                "url": f"./assets/local-swg/weapon/{role}/{weapon_gltf.name}",
                "bin": f"./assets/local-swg/weapon/{role}/{weapon_bin.name}",
                "archive": converted_entry.archive.name,
                "archivePath": str(converted_entry.archive),
                "archiveRank": converted_entry.archive_rank,
                "virtualPath": converted_entry.virtual_path,
                "shaderBindings": shader_bindings,
                "textures": weapon_textures,
                "failedTextures": failed_texture_paths,
                **weapon_summary,
            }
            print(
                f"WEAPON {role:<14} {converted_entry.archive.name} :: {converted_entry.virtual_path} "
                f"({weapon_summary['vertices']:,} vertices, {len(weapon_textures)} shader DDS textures)"
            )
    except Exception as exc:
        for role in WEAPON_MESH_RULES:
            weapon_failures.setdefault(role, str(exc))
        print(f"WEAPON conversion unavailable: {exc}")

    characters: dict[str, dict[str, Any]] = {}
    character_failures: dict[str, str] = {}
    try:
        from convert_swg_character import (
            choose_character_skeletal_mesh,
            convert_from_inventory as convert_rigged_from_inventory,
            parse_skeletal_mesh,
        )
        from convert_swg_mesh import (
            convert_from_inventory as convert_static_from_inventory,
            extract_shader_texture_paths,
            find_display_base_submeshes,
            parse_static_mesh,
        )

        for role in CHARACTER_MESH_RULES:
            static_entry = select_character_mesh(inventory, role)
            if role == "stormtrooper":
                skeletal_entry = choose_character_skeletal_mesh(inventory)
            elif role == "firstPersonHands":
                skeletal_entry = path_index.get("appearance/mesh/hum_m_hands_l0.mgn")
            else:
                skeletal_entry = None
            if static_entry is None and skeletal_entry is None:
                character_failures[role] = "no ranked character mesh candidate"
                print(f"CHARACTER miss {role}: no ranked mesh candidate")
                continue

            character_root = output_root / "character" / role
            character_entry: AssetEntry
            character_gltf: Path
            character_bin: Path
            source_submeshes: list[Any]
            hidden_submeshes: list[int] = []
            ground_offset = 0.0
            rigged = False
            converted_entry: AssetEntry
            character_summary: dict[str, Any]

            if skeletal_entry is not None:
                try:
                    character_gltf = character_root / f"{role}-rigged.gltf"
                    character_bin = character_gltf.with_suffix(".bin")
                    converted_entry, character_summary = convert_rigged_from_inventory(
                        inventory,
                        character_gltf,
                        character_bin,
                        preferred_virtual_path=skeletal_entry.virtual_path,
                    )
                    character_entry = converted_entry
                    rigged_mesh = parse_skeletal_mesh(decode_tre_entry(character_entry.archive, character_entry.metadata))
                    source_submeshes = list(rigged_mesh.submeshes)
                    ground_offset = min(
                        (position[1] for submesh in source_submeshes for position in submesh.positions),
                        default=0.0,
                    )
                    rigged = True
                    print(
                        f"CHARACTER rigged {role:<10} {converted_entry.archive.name} :: "
                        f"{converted_entry.virtual_path} ({character_summary['bones']} bones, "
                        f"{character_summary['animations']} animation clips)"
                    )
                    print(
                        f"CHARACTER skeleton {character_summary['skeletonArchive']} :: "
                        f"{character_summary['skeleton']}"
                    )
                except Exception as exc:
                    print(f"CHARACTER rigged {role:<10} unavailable: {exc}; trying static fallback")

            if not rigged:
                if static_entry is None:
                    character_failures[role] = "rigged candidate failed and no static fallback exists"
                    print(f"CHARACTER miss {role}: rigged candidate failed and no static fallback exists")
                    continue
                character_entry = static_entry
                character_gltf = character_root / f"{role}.gltf"
                character_bin = character_gltf.with_suffix(".bin")
                mesh_payload = decode_tre_entry(character_entry.archive, character_entry.metadata)
                source_submeshes = parse_static_mesh(mesh_payload)
                hidden_submeshes = (
                    find_display_base_submeshes(source_submeshes)
                    if "statue" in character_entry.virtual_path.lower()
                    else []
                )
                rendered_submeshes = [
                    submesh
                    for index, submesh in enumerate(source_submeshes)
                    if index not in hidden_submeshes
                ]
                ground_offset = min(
                    (position[1] for submesh in rendered_submeshes for position in submesh.positions),
                    default=0.0,
                )
                if hidden_submeshes:
                    print(f"CHARACTER strip {role:<11} display-base submeshes {hidden_submeshes}")
                converted_entry, character_summary = convert_static_from_inventory(
                    inventory,
                    character_gltf,
                    character_bin,
                    preferred_virtual_path=character_entry.virtual_path,
                    exclude_submesh_indices=hidden_submeshes,
                )
            shader_bindings: dict[str, list[str]] = {}
            shader_texture_paths: set[str] = set()
            for submesh in source_submeshes:
                shader_entry = path_index.get(submesh.shader.lower())
                if shader_entry is None:
                    shader_bindings[submesh.shader] = []
                    continue
                shader_paths = extract_shader_texture_paths(
                    decode_tre_entry(shader_entry.archive, shader_entry.metadata)
                )
                shader_bindings[submesh.shader] = shader_paths
                shader_texture_paths.update(shader_paths)

            character_texture_root = character_root / "texture"
            character_texture_root.mkdir(parents=True, exist_ok=True)
            (character_texture_root / ".gdignore").write_text("", encoding="utf-8")
            character_godot_texture_root = output_root / "godot" / "character" / role
            character_godot_texture_root.mkdir(parents=True, exist_ok=True)
            character_textures: dict[str, dict[str, Any]] = {}
            failed_texture_paths: dict[str, str] = {}
            for shader_texture_path in sorted(shader_texture_paths):
                texture_entry = path_index.get(shader_texture_path.lower())
                if texture_entry is None:
                    failed_texture_paths[shader_texture_path] = "shader DDS path not present in inventory"
                    continue
                destination = character_texture_root / f"{role}_{Path(shader_texture_path).name}"
                loose_path = copy_loose(source, texture_entry.virtual_path, destination)
                source_kind = "loose"
                if loose_path is None:
                    source_kind = "TRE"
                    ok, error = extract_from_tre(texture_entry.archive, texture_entry.metadata, destination)
                    if not ok:
                        failed_texture_paths[shader_texture_path] = error or "TRE extraction failed"
                        destination.unlink(missing_ok=True)
                        continue
                normalize_dds_file_for_godot(destination)
                if not is_valid_dds_file(destination):
                    failed_texture_paths[shader_texture_path] = "decoded shader reference did not have a valid DDS header"
                    destination.unlink(missing_ok=True)
                    continue
                url = f"./assets/local-swg/character/{role}/texture/{destination.name}"
                godot_url = ""
                try:
                    godot_destination = character_godot_texture_root / f"{Path(shader_texture_path).stem}.png"
                    dds_to_png_file(destination, godot_destination)
                    godot_url = f"./assets/local-swg/godot/character/{role}/{godot_destination.name}"
                except (OSError, DDSDecodeError, ValueError) as exc:
                    failed_texture_paths[shader_texture_path] = f"Godot PNG conversion failed: {exc}"

                descriptor = build_manifest_asset(texture_entry, url)
                if godot_url:
                    descriptor["godotUrl"] = godot_url
                descriptor["sourceKind"] = source_kind
                if loose_path is not None:
                    descriptor["sourcePath"] = str(loose_path.relative_to(source).as_posix())
                character_textures[shader_texture_path] = descriptor
                print(
                    f"CHARACTER texture {role:<11} {texture_entry.archive.name} :: "
                    f"{texture_entry.virtual_path} [{source_kind}]"
                )

            raw_min_y = min(
                (position[1] for submesh in source_submeshes for position in submesh.positions),
                default=0.0,
            )
            raw_max_y = max(
                (position[1] for submesh in source_submeshes for position in submesh.positions),
                default=1.0,
            )
            raw_height = max(raw_max_y - raw_min_y, 0.001)
            if role == "stormtrooper":
                recommended_scale = 1.82 / raw_height
            else:
                recommended_scale = float(
                    characters.get("stormtrooper", {}).get("recommendedScale", 1.0)
                )

            characters[role] = {
                "url": f"./assets/local-swg/character/{role}/{character_gltf.name}",
                "bin": f"./assets/local-swg/character/{role}/{character_bin.name}",
                "archive": converted_entry.archive.name,
                "archivePath": str(converted_entry.archive),
                "archiveRank": converted_entry.archive_rank,
                "virtualPath": converted_entry.virtual_path,
                "shaderBindings": shader_bindings,
                "textures": character_textures,
                "failedTextures": failed_texture_paths,
                "sourceSubmeshes": len(source_submeshes),
                "hiddenSubmeshes": hidden_submeshes,
                "groundOffset": ground_offset,
                "rawHeight": raw_height,
                "recommendedScale": recommended_scale,
                "rigged": rigged,
                "pipelineRevision": 4,
                **character_summary,
            }
            print(
                f"CHARACTER {role:<11} {converted_entry.archive.name} :: {converted_entry.virtual_path} "
                f"({character_summary['submeshes']} submeshes, {character_summary['vertices']:,} vertices, "
                f"{len(character_textures)} shader DDS textures)"
            )
    except Exception as exc:
        character_failures["stormtrooper"] = str(exc)
        print(f"CHARACTER stormtrooper unavailable: {exc}")

    manifest = {
        "schemaVersion": 2,
        "source": "local SWG Restoration client",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "decoder": {"tre": "Twofish-128 ECB + zlib", "key": "embedded Restoration client key"},
        "inventory": stats,
        "assets": manifest_assets,
        "audio": audio_assets,
        "audioFailures": audio_failures,
        "selections": selections,
        "failedRoles": failures,
        "meshCandidates": mesh_candidates,
        "meshProof": mesh_proof,
        "weapons": weapons,
        "weaponFailures": weapon_failures,
        "characterCandidates": character_candidates_all[:500],
        "characters": characters,
        "characterFailures": character_failures,
    }
    _write_json(output_root / "manifest.json", manifest)
    _write_json(
        output_root / "asset-catalog.json",
        {
            "inventory": stats,
            "meshCandidates": mesh_candidates_all,
            "characterCandidates": character_candidates_all,
        },
    )

    print()
    print(f"Imported {imported}/{len(ROLE_RULES)} curated SWG material roles.")
    print("DDS compatibility: original DDS retained for browser use; Godot-safe PNG fallbacks generated when supported.")
    if failures:
        print("Roles without a usable candidate:")
        for role, reason in failures.items():
            print(f"  {role}: {reason}")
    print(f"Manifest: {output_root / 'manifest.json'}")
    print("Local binary output is ignored by Git; only code, schema, and documentation belong in the repository.")
    return 0 if imported >= 3 else 1


if __name__ == "__main__":
    raise SystemExit(main())
