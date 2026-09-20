import json
import struct
import tempfile
import unittest
from pathlib import Path

from convert_swg_mesh import parse_static_mesh, write_gltf
from import_swg_assets import AssetEntry


def _leaf(tag: bytes, payload: bytes) -> bytes:
    return tag + struct.pack(">I", len(payload)) + payload


def _form(form_type: bytes, *children: bytes) -> bytes:
    payload = form_type + b"".join(children)
    return b"FORM" + struct.pack(">I", len(payload)) + payload


class StaticMeshConverterTests(unittest.TestCase):
    def test_parses_documented_static_mesh_subset_and_writes_gltf(self) -> None:
        vertices = b"".join(
            struct.pack("<3f3f2f", *position, 0.0, 1.0, 0.0, *uv)
            for position, uv in [((0.0, 0.0, 0.0), (0.0, 0.0)), ((1.0, 0.0, 0.0), (1.0, 0.0)), ((0.0, 1.0, 0.0), (0.0, 1.0))]
        )
        vtxa = _form(b"VTXA", _form(b"0001", _leaf(b"INFO", struct.pack("<II", 0, 3)), _leaf(b"DATA", vertices)))
        group = _form(
            b"0001",
            _leaf(b"NAME", b"shader/test.sht\x00"),
            vtxa,
            _leaf(b"INDX", struct.pack("<I3H", 3, 0, 1, 2)),
        )
        mesh = _form(b"MESH", _form(b"0005", _form(b"SPS ", _form(b"0001", _leaf(b"CNT ", struct.pack("<I", 1)), group))))

        parsed = parse_static_mesh(mesh)
        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0].shader, "shader/test.sht")
        self.assertEqual(parsed[0].indices, [0, 1, 2])

        with tempfile.TemporaryDirectory() as temp:
            gltf_path = Path(temp) / "proof.gltf"
            bin_path = Path(temp) / "proof.bin"
            summary = write_gltf(parsed, gltf_path, bin_path, AssetEntry("appearance/mesh/test.msh", Path("test.tre"), {}))
            document = json.loads(gltf_path.read_text(encoding="utf-8"))

        self.assertEqual(summary, {"submeshes": 1, "vertices": 3, "indices": 3})
        self.assertEqual(document["asset"]["version"], "2.0")
        self.assertEqual(document["meshes"][0]["primitives"][0]["attributes"]["POSITION"], 0)


if __name__ == "__main__":
    unittest.main()
