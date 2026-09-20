from __future__ import annotations

import struct
import tempfile
import unittest
import zlib
from pathlib import Path

from import_swg_assets import (
    RESTORATION_TWOFISH_KEY,
    AssetEntry,
    build_manifest_asset,
    decode_tre_entry,
    decrypt_twofish_ecb,
    is_valid_dds_payload,
    read_tre_index,
    search_entries,
    select_asset,
    static_asset_candidates,
)
from swg_twofish import encrypt_twofish_ecb


class ImporterCoreTests(unittest.TestCase):
    def test_search_is_case_insensitive_and_extension_aware(self) -> None:
        entries = [
            AssetEntry("texture/tatt_sand_bumpy.dds", Path("a.tre"), {"compression": 2}),
            AssetEntry("texture/tatt_stco_player_wall.dds", Path("b.tre"), {"compression": 2}),
            AssetEntry("appearance/mesh/mun_tato_house.msh", Path("c.tre"), {"compression": 0}),
        ]

        result = search_entries(entries, ["TATO", "SAND"], extension=".DDS")

        self.assertEqual([entry.virtual_path for entry in result], ["texture/tatt_sand_bumpy.dds"])

    def test_role_selection_is_deterministic_and_prefers_specific_path(self) -> None:
        entries = [
            AssetEntry("texture/tatt_sand_bumpy.sht", Path("bad.tre"), {"compression": 2}),
            AssetEntry("texture/desert_sand.dds", Path("z.tre"), {"compression": 2}),
            AssetEntry("texture/tatt_sand_bumpy.dds", Path("a.tre"), {"compression": 2}),
            AssetEntry("texture/tatt_sand_bumpy_n.dds", Path("a.tre"), {"compression": 2}),
        ]

        selected = select_asset(entries, "sand")

        self.assertIsNotNone(selected)
        self.assertEqual(selected.virtual_path, "texture/tatt_sand_bumpy.dds")

    def test_duplicate_virtual_paths_prefer_later_archive_rank(self) -> None:
        entries = [
            AssetEntry("texture/tatt_sand_bumpy.dds", Path("base.tre"), {"compression": 2, "archive_rank": 1}),
            AssetEntry("texture/tatt_sand_bumpy.dds", Path("patch.tre"), {"compression": 2, "archive_rank": 2}),
        ]

        selected = select_asset(entries, "sand")

        self.assertIsNotNone(selected)
        self.assertEqual(selected.archive, Path("patch.tre"))

    def test_mesh_catalog_includes_moisture_proof_and_honors_extension(self) -> None:
        entries = [
            AssetEntry("appearance/mesh/ins_all_min_moisture_s01_u0_l0.msh", Path("a.tre"), {}),
            AssetEntry("appearance/lod/mun_tato_starport_s01.lod", Path("b.tre"), {}),
            AssetEntry("texture/tatt_sand_bumpy.dds", Path("c.tre"), {}),
        ]

        candidates = static_asset_candidates(entries, ".MSH")

        self.assertEqual([entry.virtual_path for entry in candidates], ["appearance/mesh/ins_all_min_moisture_s01_u0_l0.msh"])

    def test_dds_header_validation_rejects_non_dds_payload(self) -> None:
        self.assertFalse(is_valid_dds_payload(b"DDS fixture"))
        header = bytearray(128)
        header[:4] = b"DDS "
        struct.pack_into("<III", header, 4, 124, 4, 4)
        self.assertTrue(is_valid_dds_payload(bytes(header)))

    def test_restoration_twofish_matches_known_vector(self) -> None:
        key = bytes(range(16))
        ciphertext = bytes.fromhex("9fb63337151be9c71306d159ea7afaa4")

        plaintext = decrypt_twofish_ecb(ciphertext, key)

        self.assertEqual(plaintext, bytes(range(16)))

    def test_restoration_key_decrypts_and_zlib_decodes_a_fixture(self) -> None:
        payload = b"far horizon local swg asset"
        compressed = zlib.compress(payload)
        padded = compressed + b"\x00" * ((-len(compressed)) % 16)
        encrypted = encrypt_twofish_ecb(padded, RESTORATION_TWOFISH_KEY)
        self.assertEqual(len(RESTORATION_TWOFISH_KEY), 16)

        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "encrypted.tre"
            path.write_bytes(encrypted)
            entry = {
                "file_offset": 0,
                "compressed_size": len(compressed),
                "uncompressed_size": len(payload),
                "compression": 2,
            }
            self.assertEqual(decode_tre_entry(path, entry), payload)

    def test_v6000_index_keeps_archive_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fixture.tre"
            virtual_path = b"texture/tatt_sand_bumpy.dds\x00"
            payload = b"DDS fixture"
            toc_offset = 36
            payload_offset = toc_offset + 32 + len(virtual_path)
            row = struct.pack("<6I", 0, len(payload), payload_offset, 0, len(payload), 0) + b"\x00" * 8
            header = b"EERT6000" + struct.pack(
                "<7I", 1, toc_offset, 0, len(row), 0, len(virtual_path), len(virtual_path)
            )
            path.write_bytes(header + row + virtual_path + payload)

            parsed = read_tre_index(path)

        self.assertIsNotNone(parsed)
        entry = parsed["entries"]["texture/tatt_sand_bumpy.dds"]
        self.assertEqual(entry["file_offset"], payload_offset)
        self.assertEqual(entry["archive"], path)

    def test_manifest_asset_contains_exact_source(self) -> None:
        entry = AssetEntry(
            "texture/tatt_sand_bumpy.dds",
            Path("SwgRestoration_12.tre"),
            {"compression": 2, "uncompressed_size": 128},
        )

        result = build_manifest_asset(entry, "./assets/local-swg/texture/tatt_sand_bumpy.dds")

        self.assertEqual(result["url"], "./assets/local-swg/texture/tatt_sand_bumpy.dds")
        self.assertEqual(result["archive"], "SwgRestoration_12.tre")
        self.assertEqual(result["virtualPath"], "texture/tatt_sand_bumpy.dds")


if __name__ == "__main__":
    unittest.main()
