"""Convert a small, real SWG skeletal-character chain into glTF.

This is intentionally narrower than a complete SWG appearance renderer.  It
handles the data needed for a usable Stormtrooper proof:

    FORM SKMG (.mgn) -> weighted submeshes
    FORM SLOD (.skt) -> highest-detail bone hierarchy
    FORM CKAT (.ans) -> quantized rotations and scalar translation channels

The generated asset contains a real glTF skin, inverse bind matrices, and
sampled animation channels.  It is written locally from the user's decoded
Restoration client; no SWG binary is part of the repository.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence

try:
    from convert_swg_mesh import IffNode, find_chunks, find_forms, parse_iff_nodes
    from import_swg_assets import (
        AssetEntry,
        candidate_roots,
        decode_tre_entry,
        inventory_from_archives,
    )
except ImportError:  # pragma: no cover - supports importing as tools.convert_swg_character
    from tools.convert_swg_mesh import IffNode, find_chunks, find_forms, parse_iff_nodes
    from tools.import_swg_assets import (
        AssetEntry,
        candidate_roots,
        decode_tre_entry,
        inventory_from_archives,
    )


FORM = b"FORM"


@dataclass(frozen=True)
class Quaternion:
    x: float
    y: float
    z: float
    w: float


IDENTITY_QUATERNION = Quaternion(0.0, 0.0, 0.0, 1.0)


@dataclass(frozen=True)
class SkeletonBone:
    name: str
    parent_index: int
    pre_rotation: Quaternion
    post_rotation: Quaternion
    bind_pose_rotation: Quaternion
    bind_translation: tuple[float, float, float]


@dataclass(frozen=True)
class SkeletonData:
    bones: list[SkeletonBone]


@dataclass(frozen=True)
class BoneWeight:
    bone_index: int
    weight: float


@dataclass(frozen=True)
class SkeletalSubmesh:
    shader: str
    positions: list[tuple[float, float, float]]
    normals: list[tuple[float, float, float]]
    uvs: list[tuple[float, float]]
    source_vertex_indices: list[int]
    indices: list[int]


@dataclass(frozen=True)
class SkeletalMeshData:
    skeleton_filename: str
    bone_names: list[str]
    source_positions: list[tuple[float, float, float]]
    source_normals: list[tuple[float, float, float]]
    vertex_weights: list[list[BoneWeight]]
    submeshes: list[SkeletalSubmesh]


@dataclass(frozen=True)
class RotationKeyframe:
    frame: int
    rotation: Quaternion


@dataclass(frozen=True)
class ScalarKeyframe:
    frame: int
    value: float


@dataclass
class AnimationBoneChannel:
    bone_name: str
    rotation_keyframes: list[RotationKeyframe | tuple[int, Quaternion]] = field(default_factory=list)
    translation_axis: list[list[ScalarKeyframe | tuple[int, float]]] = field(
        default_factory=lambda: [[], [], []]
    )
    has_static_rotation: bool = False
    static_rotation: Quaternion = IDENTITY_QUATERNION


@dataclass
class AnimationClipData:
    name: str
    frame_rate: float
    duration_frames: int
    bones: list[AnimationBoneChannel]
    average_translation_speed: float = 0.0
    locomotion_translation_keys: list[tuple[int, tuple[float, float, float]]] = field(default_factory=list)


def _require_root(blob: bytes, form_type: bytes) -> IffNode:
    roots = parse_iff_nodes(blob)
    if not roots or roots[0].tag != FORM or roots[0].form_type != form_type:
        readable = form_type.decode("ascii", errors="replace")
        raise ValueError(f"asset is not a FORM {readable} file")
    return roots[0]


def _first_form(node: IffNode, form_type: bytes) -> IffNode | None:
    return next(iter(find_forms(node, form_type)), None)


def _first_chunk(node: IffNode, tag: bytes, *, size: int | None = None) -> IffNode | None:
    for candidate in find_chunks(node, tag):
        if size is None or len(candidate.data) == size:
            return candidate
    return None


def _required_chunk(node: IffNode, tag: bytes, *, size: int | None = None) -> IffNode:
    chunk = _first_chunk(node, tag, size=size)
    if chunk is None:
        readable = tag.decode("ascii", errors="replace")
        suffix = f" with {size} bytes" if size is not None else ""
        raise ValueError(f"missing {readable}{suffix} chunk")
    return chunk


def _read_c_strings(data: bytes, count: int, label: str) -> list[str]:
    values: list[str] = []
    cursor = 0
    for _ in range(count):
        end = data.find(b"\x00", cursor)
        if end < 0:
            raise ValueError(f"{label} ended before {count} strings were read")
        values.append(data[cursor:end].decode("utf-8", errors="replace"))
        cursor = end + 1
    return values


def _read_file_quaternion(data: bytes, offset: int) -> Quaternion:
    # SWG writes scalar W first, followed by X/Y/Z.
    w, x, y, z = struct.unpack_from("<4f", data, offset)
    return Quaternion(x, y, z, w)


def _finite(values: Iterable[float], label: str) -> None:
    if not all(math.isfinite(value) for value in values):
        raise ValueError(f"{label} contains a non-finite value")


def parse_skeleton(blob: bytes) -> SkeletonData:
    """Parse the highest-detail FORM SKTM block from a real .skt file."""
    root = _require_root(blob, b"SLOD")
    blocks = list(find_forms(root, b"SKTM"))
    if not blocks:
        raise ValueError("SLOD contains no FORM SKTM block")

    ranked: list[tuple[int, IffNode]] = []
    for block in blocks:
        parent = _first_chunk(block, b"PRNT")
        ranked.append((len(parent.data) // 4 if parent else 0, block))
    bone_count, best = max(ranked, key=lambda item: item[0])
    if bone_count <= 0:
        raise ValueError("FORM SKTM contains no parent array")

    names = _read_c_strings(_required_chunk(best, b"NAME").data, bone_count, "skeleton NAME")
    parent_data = _required_chunk(best, b"PRNT").data
    pre_data = _required_chunk(best, b"RPRE").data
    post_data = _required_chunk(best, b"RPST").data
    translation_data = _required_chunk(best, b"BPTR").data
    bind_rotation_data = _required_chunk(best, b"BPRO").data
    if len(parent_data) < bone_count * 4:
        raise ValueError("skeleton PRNT chunk is truncated")
    if len(pre_data) < bone_count * 16 or len(post_data) < bone_count * 16:
        raise ValueError("skeleton rotation chunks are truncated")
    if len(translation_data) < bone_count * 12 or len(bind_rotation_data) < bone_count * 16:
        raise ValueError("skeleton bind-pose chunks are truncated")

    bones: list[SkeletonBone] = []
    for index, name in enumerate(names):
        parent_index = struct.unpack_from("<i", parent_data, index * 4)[0]
        pre = _read_file_quaternion(pre_data, index * 16)
        post = _read_file_quaternion(post_data, index * 16)
        bind_translation = struct.unpack_from("<3f", translation_data, index * 12)
        bind_rotation = _read_file_quaternion(bind_rotation_data, index * 16)
        _finite((*bind_translation, pre.x, pre.y, pre.z, pre.w, post.x, post.y, post.z, post.w), name)
        if parent_index >= index or parent_index < -1:
            raise ValueError(f"skeleton parent order is not glTF-compatible for bone {name!r}")
        bones.append(SkeletonBone(name, parent_index, pre, post, bind_rotation, bind_translation))
    return SkeletonData(bones)


def _read_float3_array(data: bytes, count: int, label: str) -> list[tuple[float, float, float]]:
    expected = count * 12
    if len(data) < expected:
        raise ValueError(f"{label} is truncated: expected {expected} bytes")
    result = [struct.unpack_from("<3f", data, index * 12) for index in range(count)]
    for value in result:
        _finite(value, label)
    return result


def parse_skeletal_mesh(blob: bytes) -> SkeletalMeshData:
    """Parse the weighted geometry subset used by a real FORM SKMG .mgn."""
    root = _require_root(blob, b"SKMG")
    info = _required_chunk(root, b"INFO", size=44).data
    values = struct.unpack("<11I", info)
    _unused0, _unused1, skeleton_count, bone_count, point_count, _twdt_count, normal_count, _psdt_count, _blt_count, _unused2, _unused3 = values
    if skeleton_count == 0 or bone_count == 0 or point_count == 0:
        raise ValueError("SKMG has no skeleton, bones, or points")

    skeleton_chunk = _required_chunk(root, b"SKTM")
    skeleton_filename = skeleton_chunk.data.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
    bone_names = _read_c_strings(_required_chunk(root, b"XFNM").data, bone_count, "mesh XFNM")
    positions = _read_float3_array(_required_chunk(root, b"POSN").data, point_count, "mesh POSN")
    normals = _read_float3_array(_required_chunk(root, b"NORM").data, normal_count, "mesh NORM")

    weight_counts_data = _required_chunk(root, b"TWHD").data
    if len(weight_counts_data) < point_count * 4:
        raise ValueError("mesh TWHD is truncated")
    weight_counts = [struct.unpack_from("<I", weight_counts_data, index * 4)[0] for index in range(point_count)]
    weight_data = _required_chunk(root, b"TWDT").data
    cursor = 0
    vertex_weights: list[list[BoneWeight]] = []
    for point_index, count in enumerate(weight_counts):
        weights: list[BoneWeight] = []
        for _ in range(count):
            if cursor + 8 > len(weight_data):
                raise ValueError(f"mesh TWDT is truncated at source vertex {point_index}")
            bone_index, weight = struct.unpack_from("<If", weight_data, cursor)
            cursor += 8
            if bone_index >= bone_count or not math.isfinite(weight) or weight < 0.0:
                raise ValueError(f"mesh TWDT has an invalid weight at source vertex {point_index}")
            weights.append(BoneWeight(bone_index, weight))
        vertex_weights.append(weights)

    submeshes: list[SkeletalSubmesh] = []
    for psdt in find_forms(root, b"PSDT"):
        name = _required_chunk(psdt, b"NAME").data
        shader = name.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
        pidx_data = _required_chunk(psdt, b"PIDX").data
        if len(pidx_data) < 4:
            raise ValueError("PSDT PIDX is empty")
        index_count = struct.unpack_from("<I", pidx_data)[0]
        if len(pidx_data) < 4 + index_count * 4:
            raise ValueError("PSDT PIDX is truncated")
        source_indices = [struct.unpack_from("<I", pidx_data, 4 + index * 4)[0] for index in range(index_count)]
        if any(index >= len(positions) for index in source_indices):
            raise ValueError("PSDT PIDX refers past POSN")

        nidx_data = _required_chunk(psdt, b"NIDX").data
        if len(nidx_data) < index_count * 4:
            raise ValueError("PSDT NIDX is truncated")
        normal_indices = [struct.unpack_from("<I", nidx_data, index * 4)[0] for index in range(index_count)]
        if any(index >= len(normals) for index in normal_indices):
            raise ValueError("PSDT NIDX refers past NORM")

        tcsf = _first_form(psdt, b"TCSF")
        if tcsf is None:
            raise ValueError("PSDT has no TCSF form")
        uvs_data = _required_chunk(tcsf, b"TCSD").data
        if len(uvs_data) < index_count * 8:
            raise ValueError("PSDT TCSD is truncated")
        uvs = [struct.unpack_from("<2f", uvs_data, index * 8) for index in range(index_count)]
        for uv in uvs:
            _finite(uv, "mesh UV")

        prim = _first_form(psdt, b"PRIM")
        if prim is None:
            raise ValueError("PSDT has no PRIM form")
        itl = _first_chunk(prim, b"ITL ")
        oitl = _first_chunk(prim, b"OITL") if itl is None else None
        if itl is None and oitl is None:
            raise ValueError("PSDT has no ITL or OITL triangle list")
        triangle_data = (itl or oitl).data
        if len(triangle_data) < 4:
            raise ValueError("PSDT triangle list is empty")
        triangle_count = struct.unpack_from("<I", triangle_data)[0]
        indices: list[int] = []
        if itl is not None:
            expected = 4 + triangle_count * 12
            if len(triangle_data) < expected:
                raise ValueError("PSDT ITL is truncated")
            for triangle in range(triangle_count * 3):
                index = struct.unpack_from("<I", triangle_data, 4 + triangle * 4)[0]
                if index >= index_count:
                    raise ValueError("PSDT ITL refers past PIDX")
                indices.append(index)
        else:
            expected = 4 + triangle_count * 14
            if len(triangle_data) < expected:
                raise ValueError("PSDT OITL is truncated")
            cursor = 4
            for _ in range(triangle_count):
                cursor += 2  # occlusion/group id
                for _ in range(3):
                    index = struct.unpack_from("<I", triangle_data, cursor)[0]
                    cursor += 4
                    if index >= index_count:
                        raise ValueError("PSDT OITL refers past PIDX")
                    indices.append(index)

        submeshes.append(
            SkeletalSubmesh(
                shader=shader,
                positions=[positions[index] for index in source_indices],
                normals=[normals[index] for index in normal_indices],
                uvs=uvs,
                source_vertex_indices=source_indices,
                indices=indices,
            )
        )
    if not submeshes:
        raise ValueError("SKMG contains no PSDT submeshes")
    return SkeletalMeshData(skeleton_filename, bone_names, positions, normals, vertex_weights, submeshes)


# These compact formulas reproduce the observed SWG table ranges while keeping
# the decoder readable. The official table is a sequence of equally spaced
# base values at seven precision levels.
def _base_table_entry(value: int) -> tuple[float, int]:
    ranges = (
        (0x9D, 0xBF, -0.076923072, 0.030769231, 6),
        (0xC0, 0xDF, -0.939393938, 0.060606063, 5),
        (0xE0, 0xEF, -0.882352948, 0.117647059, 4),
        (0xF0, 0xF7, -0.777777791, 0.222222222, 3),
        (0xF8, 0xFB, -0.600000024, 0.400000024, 2),
        (0xFC, 0xFD, -0.333333313, 0.666666686, 1),
    )
    if value <= 0x9D:
        return -0.076923072, 6
    if value >= 0xFD:
        return 0.333333373, 1
    for start, end, base, step, level in ranges:
        if start <= value <= end:
            return base + (value - start) * step, level
    raise ValueError(f"unhandled SWG animation context byte 0x{value:02x}")


_SCALE_TABLE = (
    (0.000977517, 0.00195695),
    (0.000651678, 0.00130463),
    (0.000391007, 0.000782779),
    (0.000217226, 0.000434877),
    (0.000115002, 0.000230229),
    (0.0000592435, 0.000118603),
    (0.0000300774, 0.0000602138),
)


def _is_finger_chain_bone(name: str) -> bool:
    return name.casefold() in {
        "lthumb01",
        "lthumb02",
        "lindex01",
        "lindex02",
        "lring01",
        "lring02",
        "rthumb01",
        "rthumb02",
        "rindex01",
        "rindex02",
        "rring01",
        "rring02",
        "lforearm",
        "lulna",
        "lwrist",
        "rforearm",
        "rulna",
        "rwrist",
    }


def decode_smallest_three_quaternion(
    compressed: int,
    context: Sequence[int],
    *,
    skip_z_negation: bool = False,
) -> Quaternion:
    """Decode the confirmed Restoration QCHN/SROT 11/11/10 layout."""
    if len(context) != 3:
        raise ValueError("SWG animation rotations require three context bytes")
    fields = ((compressed >> 21) & 0x7FF, (compressed >> 10) & 0x7FF, compressed & 0x3FF)
    decoded: list[float] = []
    for index, field in enumerate(fields):
        base, level = _base_table_entry(int(context[index]))
        if index < 2:
            negative = bool(field & 0x400)
            magnitude = field & 0x3FF
            scale = _SCALE_TABLE[level][0]
        else:
            negative = bool(field & 0x200)
            magnitude = field & 0x1FF
            scale = _SCALE_TABLE[level][1]
        delta = magnitude * scale
        decoded.append(base - delta if negative else base + delta)
    sum_squared = sum(component * component for component in decoded)
    dropped = math.sqrt(max(0.0, 1.0 - sum_squared))
    components = [decoded[0], decoded[1], decoded[2], dropped]
    length = math.sqrt(sum(component * component for component in components))
    if length > 1.0e-8:
        components = [component / length for component in components]
    z = components[2] if skip_z_negation else -components[2]
    return Quaternion(components[0], components[1], z, components[3])


def _parse_qchn(data: bytes, bone_name: str) -> list[RotationKeyframe]:
    if len(data) < 5:
        raise ValueError("QCHN is truncated")
    count = struct.unpack_from("<H", data)[0]
    context = data[2:5]
    expected = 5 + count * 6
    if len(data) < expected:
        raise ValueError("QCHN keyframe records are truncated")
    result: list[RotationKeyframe] = []
    for index in range(count):
        frame, compressed = struct.unpack_from("<HI", data, 5 + index * 6)
        result.append(
            RotationKeyframe(
                frame,
                decode_smallest_three_quaternion(
                    compressed,
                    context,
                    skip_z_negation=_is_finger_chain_bone(bone_name),
                ),
            )
        )
    return result


def _parse_chnl(data: bytes) -> list[ScalarKeyframe]:
    if len(data) < 2:
        raise ValueError("CHNL is truncated")
    count = struct.unpack_from("<H", data)[0]
    expected = 2 + count * 6
    if len(data) < expected:
        raise ValueError("CHNL keyframe records are truncated")
    return [
        ScalarKeyframe(*struct.unpack_from("<Hf", data, 2 + index * 6))
        for index in range(count)
    ]


def _parse_loct(data: bytes) -> tuple[float, list[tuple[int, tuple[float, float, float]]]]:
    if len(data) < 6:
        raise ValueError("LOCT is truncated")
    speed = struct.unpack_from("<f", data)[0]
    count = struct.unpack_from("<H", data, 4)[0]
    expected = 6 + count * 14
    if len(data) < expected:
        raise ValueError("LOCT keyframe records are truncated")
    keys = []
    for index in range(count):
        offset = 6 + index * 14
        frame = struct.unpack_from("<H", data, offset)[0]
        translation = struct.unpack_from("<3f", data, offset + 2)
        keys.append((frame, translation))
    return speed, keys


def parse_animation_clip(blob: bytes, name: str = "walk") -> AnimationClipData:
    """Parse a Restoration .ans clip, including static SROT rotations."""
    root = _require_root(blob, b"CKAT")
    clip_form = next((child for child in root.children if child.tag == FORM), None)
    if clip_form is None:
        raise ValueError("CKAT has no clip data FORM")
    xfrm = _first_form(clip_form, b"XFRM")
    arot = _first_form(clip_form, b"AROT")
    if xfrm is None or arot is None:
        raise ValueError("CKAT is missing XFRM or AROT")
    qchn = [child for child in arot.children if child.tag == b"QCHN"]
    atrn = _first_form(clip_form, b"ATRN")
    chnl = [child for child in atrn.children if child.tag == b"CHNL"] if atrn else []

    srot_chunk = _first_chunk(clip_form, b"SROT")
    static_rotations: list[tuple[Sequence[int], int]] = []
    if srot_chunk:
        if len(srot_chunk.data) % 7:
            raise ValueError("SROT size is not a multiple of seven")
        for offset in range(0, len(srot_chunk.data), 7):
            context = srot_chunk.data[offset : offset + 3]
            compressed = struct.unpack_from("<I", srot_chunk.data, offset + 3)[0]
            static_rotations.append((context, compressed))

    channels: list[AnimationBoneChannel] = []
    max_frame = 0
    for xfin in [child for child in xfrm.children if child.tag == b"XFIN"]:
        data = xfin.data
        end = data.find(b"\x00")
        if end < 0 or end + 10 > len(data):
            raise ValueError("XFIN record is truncated")
        bone_name = data[:end].decode("utf-8", errors="replace")
        offset = end + 1
        has_rotation = data[offset]
        rotation_index = struct.unpack_from("<H", data, offset + 1)[0]
        has_translation = data[offset + 3]
        translation_indices = struct.unpack_from("<3H", data, offset + 4)
        channel = AnimationBoneChannel(bone_name)

        if has_rotation and rotation_index < len(qchn):
            channel.rotation_keyframes = _parse_qchn(qchn[rotation_index].data, bone_name)
            max_frame = max([max_frame, *(key.frame for key in channel.rotation_keyframes)])
        elif not has_rotation and rotation_index < len(static_rotations):
            context, compressed = static_rotations[rotation_index]
            channel.has_static_rotation = True
            channel.static_rotation = decode_smallest_three_quaternion(
                compressed,
                context,
                skip_z_negation=_is_finger_chain_bone(bone_name),
            )

        for axis in range(3):
            if not (has_translation & (1 << (3 + axis))):
                continue
            index = translation_indices[axis]
            if index >= len(chnl):
                continue
            channel.translation_axis[axis] = _parse_chnl(chnl[index].data)
            max_frame = max([max_frame, *(key.frame for key in channel.translation_axis[axis])])
        channels.append(channel)

    average_speed = 0.0
    locomotion_keys: list[tuple[int, tuple[float, float, float]]] = []
    loct = _first_chunk(clip_form, b"LOCT")
    if loct:
        average_speed, locomotion_keys = _parse_loct(loct.data)
        max_frame = max([max_frame, *(frame for frame, _ in locomotion_keys)])

    info = _first_chunk(clip_form, b"INFO")
    frame_rate = struct.unpack_from("<f", info.data)[0] if info and len(info.data) >= 4 else 30.0
    if not math.isfinite(frame_rate) or frame_rate <= 0.0 or frame_rate > 240.0:
        frame_rate = 30.0
    return AnimationClipData(name, frame_rate, max_frame + 1, channels, average_speed, locomotion_keys)


def _quaternion_normalize(value: Quaternion) -> Quaternion:
    length = math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z + value.w * value.w)
    return IDENTITY_QUATERNION if length <= 1.0e-8 else Quaternion(value.x / length, value.y / length, value.z / length, value.w / length)


def _quaternion_multiply(lhs: Quaternion, rhs: Quaternion) -> Quaternion:
    # SWG's real client composes animation * bind, then post * (...) * pre.
    return Quaternion(
        lhs.w * rhs.x + rhs.w * lhs.x + lhs.y * rhs.z - lhs.z * rhs.y,
        lhs.w * rhs.y + rhs.w * lhs.y + lhs.z * rhs.x - lhs.x * rhs.z,
        lhs.w * rhs.z + rhs.w * lhs.z + lhs.x * rhs.y - lhs.y * rhs.x,
        lhs.w * rhs.w - (lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z),
    )


def _quaternion_negate(value: Quaternion) -> Quaternion:
    return Quaternion(-value.x, -value.y, -value.z, -value.w)


def _quaternion_slerp(lhs: Quaternion, rhs: Quaternion, amount: float) -> Quaternion:
    lhs = _quaternion_normalize(lhs)
    rhs = _quaternion_normalize(rhs)
    dot = lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z + lhs.w * rhs.w
    if dot < 0.0:
        rhs = _quaternion_negate(rhs)
        dot = -dot
    if dot > 0.9995:
        return _quaternion_normalize(
            Quaternion(
                lhs.x + amount * (rhs.x - lhs.x),
                lhs.y + amount * (rhs.y - lhs.y),
                lhs.z + amount * (rhs.z - lhs.z),
                lhs.w + amount * (rhs.w - lhs.w),
            )
        )
    theta = math.acos(max(-1.0, min(1.0, dot)))
    sin_theta = math.sin(theta)
    left_weight = math.sin((1.0 - amount) * theta) / sin_theta
    right_weight = math.sin(amount * theta) / sin_theta
    return Quaternion(
        lhs.x * left_weight + rhs.x * right_weight,
        lhs.y * left_weight + rhs.y * right_weight,
        lhs.z * left_weight + rhs.z * right_weight,
        lhs.w * left_weight + rhs.w * right_weight,
    )


def _keyframe_rotation(key: RotationKeyframe | tuple[int, Quaternion]) -> RotationKeyframe:
    return key if isinstance(key, RotationKeyframe) else RotationKeyframe(key[0], key[1])


def _keyframe_scalar(key: ScalarKeyframe | tuple[int, float]) -> ScalarKeyframe:
    return key if isinstance(key, ScalarKeyframe) else ScalarKeyframe(key[0], key[1])


def _sample_rotation(keys: Sequence[RotationKeyframe | tuple[int, Quaternion]], frame: int) -> Quaternion:
    values = sorted((_keyframe_rotation(key) for key in keys), key=lambda key: key.frame)
    if not values:
        return IDENTITY_QUATERNION
    if len(values) == 1:
        return values[0].rotation
    period = max(values[-1].frame + 1, 1)
    target = frame % period
    if target < values[0].frame:
        left = values[-1]
        right = values[0]
        right_frame = values[0].frame + period
        amount = (target + period - left.frame) / max(right_frame - left.frame, 1)
        return _quaternion_slerp(left.rotation, right.rotation, amount)
    for left, right in zip(values, values[1:]):
        if target <= right.frame:
            amount = (target - left.frame) / max(right.frame - left.frame, 1)
            return _quaternion_slerp(left.rotation, right.rotation, amount)
    left = values[-1]
    right = values[0]
    amount = (target - left.frame) / max(period - left.frame, 1)
    return _quaternion_slerp(left.rotation, right.rotation, amount)


def _sample_scalar(keys: Sequence[ScalarKeyframe | tuple[int, float]], frame: int) -> float:
    values = sorted((_keyframe_scalar(key) for key in keys), key=lambda key: key.frame)
    if not values:
        return 0.0
    if len(values) == 1:
        return values[0].value
    period = max(values[-1].frame + 1, 1)
    target = frame % period
    if target < values[0].frame:
        left = values[-1]
        right = values[0]
        right_frame = values[0].frame + period
        amount = (target + period - left.frame) / max(right_frame - left.frame, 1)
        return left.value + (right.value - left.value) * amount
    for left, right in zip(values, values[1:]):
        if target <= right.frame:
            amount = (target - left.frame) / max(right.frame - left.frame, 1)
            return left.value + (right.value - left.value) * amount
    left = values[-1]
    right = values[0]
    amount = (target - left.frame) / max(period - left.frame, 1)
    return left.value + (right.value - left.value) * amount


def _channel_map(clip: AnimationClipData) -> dict[str, AnimationBoneChannel]:
    return {channel.bone_name.casefold(): channel for channel in clip.bones}


def _sample_local_transform(
    bone: SkeletonBone,
    channel: AnimationBoneChannel | None,
    frame: int,
    *,
    omit_root_horizontal_translation: bool = True,
) -> tuple[Quaternion, tuple[float, float, float]]:
    animation_rotation = IDENTITY_QUATERNION
    if channel:
        if channel.rotation_keyframes:
            animation_rotation = _sample_rotation(channel.rotation_keyframes, frame)
        elif channel.has_static_rotation:
            animation_rotation = channel.static_rotation
    animated_rotation = _quaternion_multiply(animation_rotation, bone.bind_pose_rotation)
    rotation = _quaternion_normalize(
        _quaternion_multiply(bone.post_rotation, _quaternion_multiply(animated_rotation, bone.pre_rotation))
    )
    translation = list(bone.bind_translation)
    if channel:
        for axis in range(3):
            delta = _sample_scalar(channel.translation_axis[axis], frame)
            if omit_root_horizontal_translation and bone.name.casefold() == "root" and axis in (0, 2):
                delta = 0.0
            translation[axis] += delta
    return rotation, (translation[0], translation[1], translation[2])


def _quat_matrix(value: Quaternion) -> list[list[float]]:
    q = _quaternion_normalize(value)
    xx, yy, zz = q.x * q.x, q.y * q.y, q.z * q.z
    xy, xz, yz = q.x * q.y, q.x * q.z, q.y * q.z
    wx, wy, wz = q.w * q.x, q.w * q.y, q.w * q.z
    return [
        [1.0 - 2.0 * (yy + zz), 2.0 * (xy - wz), 2.0 * (xz + wy), 0.0],
        [2.0 * (xy + wz), 1.0 - 2.0 * (xx + zz), 2.0 * (yz - wx), 0.0],
        [2.0 * (xz - wy), 2.0 * (yz + wx), 1.0 - 2.0 * (xx + yy), 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _trs_matrix(rotation: Quaternion, translation: tuple[float, float, float]) -> list[list[float]]:
    matrix = _quat_matrix(rotation)
    matrix[0][3], matrix[1][3], matrix[2][3] = translation
    return matrix


def _matrix_multiply(lhs: list[list[float]], rhs: list[list[float]]) -> list[list[float]]:
    return [
        [sum(lhs[row][inner] * rhs[inner][column] for inner in range(4)) for column in range(4)]
        for row in range(4)
    ]


def _rigid_inverse(matrix: list[list[float]]) -> list[list[float]]:
    result = [[0.0] * 4 for _ in range(4)]
    for row in range(3):
        for column in range(3):
            result[row][column] = matrix[column][row]
    for row in range(3):
        result[row][3] = -sum(result[row][column] * matrix[column][3] for column in range(3))
    result[3][3] = 1.0
    return result


def _gltf_matrix(matrix: list[list[float]]) -> list[float]:
    return [matrix[row][column] for column in range(4) for row in range(4)]


def _bounds(values: Sequence[tuple[float, float, float]]) -> tuple[list[float], list[float]]:
    return (
        [min(value[index] for value in values) for index in range(3)],
        [max(value[index] for value in values) for index in range(3)],
    )


def write_skinned_gltf(
    mesh: SkeletalMeshData,
    skeleton: SkeletonData,
    animations: Sequence[AnimationClipData],
    output_gltf: Path,
    output_bin: Path,
    source: AssetEntry,
) -> dict[str, int | bool]:
    """Write weighted submeshes, a skeleton skin, and sampled glTF clips."""
    if not skeleton.bones:
        raise ValueError("cannot write a character without skeleton bones")
    skeleton_by_name = {bone.name.casefold(): index for index, bone in enumerate(skeleton.bones)}
    mesh_to_joint: dict[int, int] = {}
    for mesh_index, mesh_name in enumerate(mesh.bone_names):
        skeleton_index = skeleton_by_name.get(mesh_name.casefold())
        if skeleton_index is not None:
            mesh_to_joint[mesh_index] = skeleton_index
    if not mesh_to_joint:
        raise ValueError("mesh and skeleton have no matching bone names")
    root_skeleton_index = next(
        (index for index, bone in enumerate(skeleton.bones) if bone.parent_index < 0),
        0,
    )

    buffer = bytearray()
    buffer_views: list[dict] = []
    accessors: list[dict] = []
    materials: list[dict] = []
    meshes: list[dict] = []

    def append_blob(data: bytes, *, target: int | None = None) -> int:
        while len(buffer) % 4:
            buffer.append(0)
        offset = len(buffer)
        buffer.extend(data)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            view["target"] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    def add_accessor(
        data: bytes,
        component_type: int,
        count: int,
        accessor_type: str,
        *,
        target: int | None = None,
        minimum: list[float | int] | None = None,
        maximum: list[float | int] | None = None,
        normalized: bool = False,
    ) -> int:
        view = append_blob(data, target=target)
        accessor = {
            "bufferView": view,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if normalized:
            accessor["normalized"] = True
        if minimum is not None:
            accessor["min"] = minimum
        if maximum is not None:
            accessor["max"] = maximum
        accessors.append(accessor)
        return len(accessors) - 1

    for submesh_index, submesh in enumerate(mesh.submeshes):
        joints: list[tuple[int, int, int, int]] = []
        weights: list[tuple[float, float, float, float]] = []
        for source_index in submesh.source_vertex_indices:
            candidates = [
                (mesh_to_joint[weight.bone_index], weight.weight)
                for weight in mesh.vertex_weights[source_index]
                if weight.bone_index in mesh_to_joint and weight.weight > 0.0
            ]
            candidates.sort(key=lambda item: (-item[1], item[0]))
            candidates = candidates[:4]
            if not candidates:
                candidates = [(root_skeleton_index, 1.0)]
            total = sum(weight for _, weight in candidates) or 1.0
            candidates = [(joint, weight / total) for joint, weight in candidates]
            while len(candidates) < 4:
                candidates.append((candidates[0][0], 0.0))
            joints.append(tuple(mesh_to_joint_index for mesh_to_joint_index, _ in candidates))
            weights.append(tuple(weight for _, weight in candidates))

        position_min, position_max = _bounds(submesh.positions)
        position_accessor = add_accessor(
            b"".join(struct.pack("<3f", *value) for value in submesh.positions),
            5126,
            len(submesh.positions),
            "VEC3",
            target=34962,
            minimum=position_min,
            maximum=position_max,
        )
        normal_accessor = add_accessor(
            b"".join(struct.pack("<3f", *value) for value in submesh.normals),
            5126,
            len(submesh.normals),
            "VEC3",
            target=34962,
        )
        uv_accessor = add_accessor(
            b"".join(struct.pack("<2f", *value) for value in submesh.uvs),
            5126,
            len(submesh.uvs),
            "VEC2",
            target=34962,
        )
        joint_accessor = add_accessor(
            b"".join(struct.pack("<4B", *value) for value in joints),
            5121,
            len(joints),
            "VEC4",
            target=34962,
        )
        weight_accessor = add_accessor(
            b"".join(struct.pack("<4f", *value) for value in weights),
            5126,
            len(weights),
            "VEC4",
            target=34962,
        )
        max_index = max(submesh.indices, default=0)
        index_component = 5123 if max_index < 65536 else 5125
        index_format = "<H" if index_component == 5123 else "<I"
        index_accessor = add_accessor(
            b"".join(struct.pack(index_format, index) for index in submesh.indices),
            index_component,
            len(submesh.indices),
            "SCALAR",
            target=34963,
            minimum=[0],
            maximum=[max_index],
        )
        material_index = len(materials)
        materials.append(
            {
                "name": submesh.shader or f"swg-character-material-{submesh_index}",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.92, 0.92, 0.92, 1.0],
                    "metallicFactor": 0.05,
                    "roughnessFactor": 0.42,
                },
                "extras": {"swgShader": submesh.shader},
            }
        )
        meshes.append(
            {
                "name": f"swg-character-submesh-{submesh_index}",
                "primitives": [
                    {
                        "attributes": {
                            "POSITION": position_accessor,
                            "NORMAL": normal_accessor,
                            "TEXCOORD_0": uv_accessor,
                            "JOINTS_0": joint_accessor,
                            "WEIGHTS_0": weight_accessor,
                        },
                        "indices": index_accessor,
                        "material": material_index,
                        "mode": 4,
                    }
                ],
            }
        )

    bind_local: list[list[list[float]]] = []
    bind_world: list[list[list[float]]] = []
    for bone in skeleton.bones:
        rotation, translation = _sample_local_transform(bone, None, 0)
        local = _trs_matrix(rotation, translation)
        bind_local.append(local)
        if bone.parent_index < 0:
            bind_world.append(local)
        else:
            bind_world.append(_matrix_multiply(bind_world[bone.parent_index], local))
    inverse_bind_data = b"".join(
        struct.pack("<16f", *_gltf_matrix(_rigid_inverse(matrix))) for matrix in bind_world
    )
    inverse_bind_accessor = add_accessor(inverse_bind_data, 5126, len(skeleton.bones), "MAT4")

    # Node zero is an identity presentation root. Bone nodes follow so their
    # indices are stable and the skin's JOINTS_0 values remain compact.
    nodes: list[dict] = [{"name": "stormtrooper-rig"}]
    bone_node_indices: list[int] = []
    for bone_index, bone in enumerate(skeleton.bones):
        rotation, translation = _sample_local_transform(bone, None, 0)
        node = {
            "name": bone.name,
            "translation": list(translation),
            "rotation": [rotation.x, rotation.y, rotation.z, rotation.w],
        }
        bone_node_indices.append(len(nodes))
        nodes.append(node)
    for bone_index, bone in enumerate(skeleton.bones):
        if bone.parent_index >= 0:
            nodes[bone_node_indices[bone.parent_index]].setdefault("children", []).append(bone_node_indices[bone_index])
        else:
            nodes[0].setdefault("children", []).append(bone_node_indices[bone_index])

    for mesh_index, mesh_document in enumerate(meshes):
        node_index = len(nodes)
        nodes.append({"name": mesh_document["name"], "mesh": mesh_index, "skin": 0})
        nodes[0].setdefault("children", []).append(node_index)

    animation_documents: list[dict] = []
    for clip in animations:
        fps = clip.frame_rate if clip.frame_rate > 0.0 else 30.0
        last_frame = max(clip.duration_frames, 1)
        frame_numbers = list(range(last_frame + 1))
        times = [frame / fps for frame in frame_numbers]
        time_accessor = add_accessor(
            b"".join(struct.pack("<f", value) for value in times),
            5126,
            len(times),
            "SCALAR",
            minimum=[times[0]],
            maximum=[times[-1]],
        )
        channel_map = _channel_map(clip)
        samplers: list[dict] = []
        channels: list[dict] = []
        for bone_index, bone in enumerate(skeleton.bones):
            channel = channel_map.get(bone.name.casefold())
            has_rotation = bool(
                channel
                and (channel.rotation_keyframes or channel.has_static_rotation)
            )
            has_translation = bool(channel and any(channel.translation_axis[axis] for axis in range(3)))
            if has_rotation:
                values: list[Quaternion] = []
                previous: Quaternion | None = None
                for frame in frame_numbers:
                    rotation, _translation = _sample_local_transform(bone, channel, frame)
                    if previous is not None and (
                        rotation.x * previous.x
                        + rotation.y * previous.y
                        + rotation.z * previous.z
                        + rotation.w * previous.w
                    ) < 0.0:
                        rotation = _quaternion_negate(rotation)
                    values.append(rotation)
                    previous = rotation
                output_accessor = add_accessor(
                    b"".join(struct.pack("<4f", value.x, value.y, value.z, value.w) for value in values),
                    5126,
                    len(values),
                    "VEC4",
                )
                samplers.append({"input": time_accessor, "output": output_accessor, "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": bone_node_indices[bone_index], "path": "rotation"}})
            if has_translation:
                translations: list[tuple[float, float, float]] = []
                for frame in frame_numbers:
                    _rotation, translation = _sample_local_transform(bone, channel, frame)
                    translations.append(translation)
                output_accessor = add_accessor(
                    b"".join(struct.pack("<3f", *value) for value in translations),
                    5126,
                    len(translations),
                    "VEC3",
                )
                samplers.append({"input": time_accessor, "output": output_accessor, "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": bone_node_indices[bone_index], "path": "translation"}})
        animation_documents.append({"name": clip.name, "samplers": samplers, "channels": channels})

    document = {
        "asset": {"version": "2.0", "generator": "Far Horizon local SWG skeletal converter"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "skins": [{"name": "all_b", "skeleton": bone_node_indices[root_skeleton_index], "joints": bone_node_indices, "inverseBindMatrices": inverse_bind_accessor}],
        "animations": animation_documents,
        "buffers": [{"byteLength": len(buffer), "uri": output_bin.name}],
        "bufferViews": buffer_views,
        "accessors": accessors,
        "extras": {
            "sourceArchive": source.archive.name,
            "sourceVirtualPath": source.virtual_path,
            "conversion": "SWG FORM SKMG + SLOD + CKAT -> glTF 2.0 skin",
            "skeleton": "appearance/skeleton/all_b.skt",
            "animationClips": [clip.name for clip in animations],
        },
    }
    output_gltf.parent.mkdir(parents=True, exist_ok=True)
    output_bin.parent.mkdir(parents=True, exist_ok=True)
    output_bin.write_bytes(buffer)
    output_gltf.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    return {
        "submeshes": len(meshes),
        "vertices": sum(len(submesh.positions) for submesh in mesh.submeshes),
        "indices": sum(len(submesh.indices) for submesh in mesh.submeshes),
        "bones": len(skeleton.bones),
        "skins": 1,
        "animations": len(animation_documents),
        "rigged": True,
    }


def _ranked_entry(entries: Iterable[AssetEntry], paths: Sequence[str], extension: str, terms: Sequence[str]) -> AssetEntry | None:
    entries = list(entries)
    for path in paths:
        exact = [entry for entry in entries if entry.virtual_path.casefold() == path.casefold()]
        if exact:
            exact.sort(key=lambda entry: (-entry.archive_rank, entry.archive.name.casefold()))
            return exact[0]
    candidates = [
        entry
        for entry in entries
        if entry.extension == extension and all(term.casefold() in entry.virtual_path.casefold() for term in terms)
    ]
    candidates.sort(key=lambda entry: (-entry.archive_rank, entry.virtual_path.casefold(), entry.archive.name.casefold()))
    return candidates[0] if candidates else None


def choose_character_skeletal_mesh(entries: Iterable[AssetEntry]) -> AssetEntry | None:
    return _ranked_entry(
        entries,
        ("appearance/mesh/stormtrooper_l0.mgn",),
        ".mgn",
        ("stormtrooper",),
    )


def convert_from_inventory(
    entries: Iterable[AssetEntry],
    output_gltf: Path,
    output_bin: Path,
    *,
    preferred_virtual_path: str | None = None,
) -> tuple[AssetEntry, dict[str, int | bool | list[str]]]:
    entries = list(entries)
    mesh_entry = _ranked_entry(
        entries,
        (preferred_virtual_path,) if preferred_virtual_path else ("appearance/mesh/stormtrooper_l0.mgn",),
        ".mgn",
        ("stormtrooper",),
    )
    if mesh_entry is None:
        raise FileNotFoundError("no Stormtrooper .mgn candidate found")
    mesh = parse_skeletal_mesh(decode_tre_entry(mesh_entry.archive, mesh_entry.metadata))
    skeleton_entry = _ranked_entry(
        entries,
        (mesh.skeleton_filename, "appearance/skeleton/all_b.skt"),
        ".skt",
        ("all_b",),
    )
    if skeleton_entry is None:
        raise FileNotFoundError(f"mesh references missing skeleton {mesh.skeleton_filename!r}")
    skeleton = parse_skeleton(decode_tre_entry(skeleton_entry.archive, skeleton_entry.metadata))

    animation_specs = (
        ("idle", ("appearance/animation/all_b_cbt_rifle_standing_ready_idle_front_left.ans", "appearance/animation/all_b_ad_stormtrooper1.ans")),
        # This is the clean full-body gait clip. The rifle-ready clip remains
        # a real source in the client and is preferable for a later combat
        # stance, but the locomotion clip gives the playable avatar a natural
        # walk while the weapon presentation stays readable.
        ("walk", ("appearance/animation/all_b_loc_walk_male.ans", "appearance/animation/all_b_cbt_rifle_walk_ready.ans")),
        ("run", ("appearance/animation/all_b_loc_run_rifle_storm_trooper.ans",)),
    )
    animations: list[AnimationClipData] = []
    selected_animation_paths: list[str] = []
    for animation_name, preferred_paths in animation_specs:
        animation_entry = _ranked_entry(entries, preferred_paths, ".ans", ("all_b",))
        if animation_entry is None:
            print(f"CHARACTER animation miss {animation_name}: no ranked .ans candidate")
            continue
        clip = parse_animation_clip(decode_tre_entry(animation_entry.archive, animation_entry.metadata), animation_name)
        animations.append(clip)
        selected_animation_paths.append(animation_entry.virtual_path)
        print(f"CHARACTER animation {animation_name:<5} {animation_entry.archive.name} :: {animation_entry.virtual_path}")
    if not animations:
        raise ValueError("no usable all_b Stormtrooper animation clips found")

    summary = write_skinned_gltf(mesh, skeleton, animations, output_gltf, output_bin, mesh_entry)
    summary["skeleton"] = skeleton_entry.virtual_path
    summary["animationPaths"] = selected_animation_paths
    return mesh_entry, summary


def convert_from_client(source: Path, output_gltf: Path, output_bin: Path) -> tuple[AssetEntry, dict]:
    tre_files = sorted(path for path in source.rglob("*") if path.is_file() and path.suffix.lower() == ".tre")
    inventory, _stats = inventory_from_archives(tre_files)
    return convert_from_inventory(inventory, output_gltf, output_bin)


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract a local SWG skeletal character and convert it to glTF.")
    parser.add_argument("--source", "-s", help="Path to your SWG Restoration client folder.")
    parser.add_argument("--output", help="Output .gltf path (defaults to assets/local-swg/character/stormtrooper/stormtrooper-rigged.gltf)")
    args = parser.parse_args()
    roots = candidate_roots(args.source)
    if not roots:
        print("Could not find an SWG Restoration install. Use --source.", file=sys.stderr)
        return 2
    project_root = Path(__file__).resolve().parents[1]
    output_gltf = Path(args.output) if args.output else project_root / "assets/local-swg/character/stormtrooper/stormtrooper-rigged.gltf"
    output_bin = output_gltf.with_suffix(".bin")
    try:
        entry, summary = convert_from_client(roots[0], output_gltf, output_bin)
    except Exception as exc:
        print(f"Character conversion failed: {exc}", file=sys.stderr)
        return 1
    print(f"Converted {entry.archive.name} :: {entry.virtual_path}")
    print(f"glTF: {output_gltf}")
    print(
        f"Rig: {summary['bones']} bones, {summary['skins']} skin, "
        f"{summary['animations']} animation clips, {summary['vertices']:,} vertices"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
