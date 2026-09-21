import json
import struct
import tempfile
import unittest
from pathlib import Path

from convert_swg_character import (
    AnimationBoneChannel,
    AnimationClipData,
    Quaternion,
    character_animation_specs,
    choose_character_skeletal_mesh,
    write_skinned_gltf,
    parse_skeletal_mesh,
    parse_skeleton,
)
from import_swg_assets import AssetEntry


def _leaf(tag: bytes, payload: bytes) -> bytes:
    return tag + struct.pack(">I", len(payload)) + payload


def _form(form_type: bytes, *children: bytes) -> bytes:
    payload = form_type + b"".join(children)
    return b"FORM" + struct.pack(">I", len(payload)) + payload


def _one_bone_skeleton() -> bytes:
    bone_form = _form(
        b"0002",
        _leaf(b"NAME", b"root\x00"),
        _leaf(b"PRNT", struct.pack("<i", -1)),
        _leaf(b"RPRE", struct.pack("<4f", 1.0, 0.0, 0.0, 0.0)),
        _leaf(b"RPST", struct.pack("<4f", 1.0, 0.0, 0.0, 0.0)),
        _leaf(b"BPTR", struct.pack("<3f", 0.0, 1.0, 0.0)),
        _leaf(b"BPRO", struct.pack("<4f", 1.0, 0.0, 0.0, 0.0)),
    )
    return _form(b"SLOD", _form(b"SKTM", bone_form))


def _one_bone_mesh() -> bytes:
    positions = [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)]
    normals = [(0.0, 0.0, 1.0)] * 3
    info = struct.pack("<11I", 0, 0, 1, 1, 3, 3, 3, 1, 0, 0, 0)
    weights = b"".join(struct.pack("<If", 0, 1.0) for _ in positions)
    psdt = _form(
        b"PSDT",
        _leaf(b"NAME", b"shader/test.sht\x00"),
        _leaf(b"PIDX", struct.pack("<I3I", 3, 0, 1, 2)),
        _leaf(b"NIDX", struct.pack("<3I", 0, 0, 0)),
        _form(b"TCSF", _leaf(b"TCSD", struct.pack("<6f", 0.0, 0.0, 1.0, 0.0, 0.0, 1.0))),
        _form(b"PRIM", _leaf(b"ITL ", struct.pack("<I3I", 1, 0, 1, 2))),
    )
    return _form(
        b"SKMG",
        _form(
            b"0004",
            _leaf(b"INFO", info),
            _leaf(b"SKTM", b"appearance/skeleton/all_b.skt\x00"),
            _leaf(b"XFNM", b"root\x00"),
            _leaf(b"POSN", b"".join(struct.pack("<3f", *value) for value in positions)),
            _leaf(b"NORM", b"".join(struct.pack("<3f", *value) for value in normals)),
            _leaf(b"TWHD", struct.pack("<3I", 1, 1, 1)),
            _leaf(b"TWDT", weights),
            psdt,
            _form(
                b"HPTS",
                _form(
                    b"HPNT",
                    _leaf(b"NAME", b"hp_weapon_right\x00root\x00"),
                    _leaf(
                        b"DATA",
                        struct.pack(
                            "<7f",
                            0.12,
                            0.34,
                            -0.08,
                            1.0,
                            0.0,
                            0.0,
                            0.0,
                        ),
                    ),
                ),
            ),
        ),
    )


class SkinnedCharacterConverterTests(unittest.TestCase):
    def test_parses_real_format_skeleton_and_mesh_weights(self) -> None:
        skeleton = parse_skeleton(_one_bone_skeleton())
        mesh = parse_skeletal_mesh(_one_bone_mesh())

        self.assertEqual([bone.name for bone in skeleton.bones], ["root"])
        self.assertEqual(skeleton.bones[0].parent_index, -1)
        self.assertEqual(mesh.skeleton_filename, "appearance/skeleton/all_b.skt")
        self.assertEqual(mesh.bone_names, ["root"])
        self.assertEqual(mesh.vertex_weights[0][0].bone_index, 0)
        self.assertEqual(mesh.submeshes[0].source_vertex_indices, [0, 1, 2])
        self.assertEqual(len(mesh.hardpoints), 1)
        self.assertEqual(mesh.hardpoints[0].name, "hp_weapon_right")
        self.assertEqual(mesh.hardpoints[0].parent_joint_name, "root")

    def test_writes_a_glb_compatible_skin_and_animation(self) -> None:
        skeleton = parse_skeleton(_one_bone_skeleton())
        mesh = parse_skeletal_mesh(_one_bone_mesh())
        animation = AnimationClipData(
            name="walk",
            frame_rate=30.0,
            duration_frames=2,
            average_translation_speed=1.5,
            bones=[
                AnimationBoneChannel(
                    bone_name="root",
                    rotation_keyframes=[
                        (0, Quaternion(0.0, 0.0, 0.0, 1.0)),
                        (2, Quaternion(0.0, 0.1, 0.0, 0.995)),
                    ],
                )
            ],
        )
        source = AssetEntry("appearance/mesh/test.mgn", Path("test.tre"), {})

        with tempfile.TemporaryDirectory() as temp:
            gltf_path = Path(temp) / "stormtrooper.gltf"
            bin_path = Path(temp) / "stormtrooper.bin"
            summary = write_skinned_gltf(mesh, skeleton, [animation], gltf_path, bin_path, source)
            document = json.loads(gltf_path.read_text(encoding="utf-8"))

        self.assertEqual(summary["skins"], 1)
        self.assertEqual(summary["animations"], 1)
        self.assertEqual(document["skins"][0]["joints"], [1])
        attributes = document["meshes"][0]["primitives"][0]["attributes"]
        self.assertIn("JOINTS_0", attributes)
        self.assertIn("WEIGHTS_0", attributes)
        self.assertEqual(document["animations"][0]["name"], "walk")
        self.assertEqual(summary["animationSpeeds"], {"walk": 1.5})
        self.assertEqual(summary["hardpointNames"], ["hp_weapon_right"])
        hardpoint_node = next(node for node in document["nodes"] if node["name"] == "hp_weapon_right")
        self.assertEqual(hardpoint_node["extras"]["parentJoint"], "root")

    def test_prefers_the_highest_ranked_exact_skeletal_mesh_path(self) -> None:
        older = AssetEntry(
            "appearance/mesh/stormtrooper_l0.mgn",
            Path("old.tre"),
            {"archive_rank": 2},
        )
        newer = AssetEntry(
            "appearance/mesh/stormtrooper_l0.mgn",
            Path("new.tre"),
            {"archive_rank": 8},
        )

        self.assertEqual(choose_character_skeletal_mesh([older, newer]), newer)

    def test_prefers_rifle_ready_character_clips_for_weapon_pose_and_fire(self) -> None:
        specs = {
            name: (preferred_paths, fallback_terms)
            for name, preferred_paths, fallback_terms in character_animation_specs()
        }
        self.assertEqual(
            specs["walk"][0][0],
            "appearance/animation/all_b_cbt_rifle_walk_ready.ans",
        )
        self.assertEqual(
            specs["fire"][0][0],
            "appearance/animation/all_b_cbt_rifle_standing_aimed_fire_1_front_left.ans",
        )
        self.assertEqual(
            specs["death"][0][0],
            "appearance/animation/all_b_npc_death_pose_2.ans",
        )
        self.assertIn("rifle", specs["fire"][1])


if __name__ == "__main__":
    unittest.main()
