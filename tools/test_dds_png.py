from __future__ import annotations

import struct
import unittest
import zlib

from dds_png import decode_dds_rgba, dds_to_png_bytes


def _dxt1_fixture() -> bytes:
    header = bytearray(128)
    header[:4] = b"DDS "
    struct.pack_into("<I", header, 4, 124)
    struct.pack_into("<I", header, 8, 0x00081007)
    struct.pack_into("<I", header, 12, 4)
    struct.pack_into("<I", header, 16, 4)
    struct.pack_into("<I", header, 20, 8)
    struct.pack_into("<I", header, 76, 32)
    struct.pack_into("<I", header, 80, 0x4)
    header[84:88] = b"DXT1"
    struct.pack_into("<I", header, 108, 0x1000)

    # RGB565 red as color0, black as color1, all pixels choose color0.
    block = struct.pack("<HHI", 0xF800, 0x0000, 0)
    return bytes(header) + block


class DdsPngTests(unittest.TestCase):
    def test_decodes_dxt1_top_level_to_rgba(self) -> None:
        width, height, rgba = decode_dds_rgba(_dxt1_fixture())

        self.assertEqual((width, height), (4, 4))
        self.assertEqual(len(rgba), 4 * 4 * 4)
        self.assertEqual(rgba[:4], bytes((255, 0, 0, 255)))

    def test_writes_valid_png_without_external_dependencies(self) -> None:
        png = dds_to_png_bytes(_dxt1_fixture())

        self.assertTrue(png.startswith(b"\x89PNG\r\n\x1a\n"))
        self.assertIn(b"IHDR", png)
        self.assertIn(b"IDAT", png)
        self.assertTrue(png.endswith(b"IEND\xaeB\x60\x82"))


if __name__ == "__main__":
    unittest.main()
