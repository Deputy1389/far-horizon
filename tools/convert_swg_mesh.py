"""Convert one locally decoded SWG static MSH into a small glTF asset.

This is intentionally a narrow proof, not a complete SWG appearance pipeline.
It reads the documented static-mesh subset (FORM MESH -> FORM SPS -> VTXA /
INDX), preserves one UV set and shader names as glTF extras, and leaves shader
texture resolution to Far Horizon's local material library. No client bytes
are checked into the repository; the input is decoded from the user's local
Restoration TRE files at import time.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from import_swg_assets import AssetEntry, candidate_roots, decode_tre_entry, inventory_from_archives
except ImportError:  # pragma: no cover - supports importing as tools.convert_swg_mesh
    from tools.import_swg_assets import AssetEntry, candidate_roots, decode_tre_entry, inventory_from_archives


FORM = b"FORM"


@dataclass
class IffNode:
    tag: bytes
    form_type: bytes | None
    data: bytes
    children: list["IffNode"]


@dataclass
class MeshSubmesh:
    shader: str
    positions: list[tuple[float, float, float]]
    normals: list[tuple[float, float, float]]
    uvs: list[tuple[float, float]]
    indices: list[int]


def parse_iff_nodes(blob: bytes, start: int = 0, end: int | None = None) -> list[IffNode]:
    """Parse the big-endian IFF envelope used by SWG assets.

    SWG's IFF reader consumes exactly the declared chunk size; there is no
    implicit padding between chunks in the client format.
    """
    end = len(blob) if end is None else end
    nodes: list[IffNode] = []
    cursor = start
    while cursor + 8 <= end:
        tag = blob[cursor : cursor + 4]
        size = struct.unpack_from(">I", blob, cursor + 4)[0]
        payload_start = cursor + 8
        payload_end = payload_start + size
        if payload_end > end:
            raise ValueError(f"IFF chunk {tag!r} overruns its parent")
        if tag == FORM:
            if size < 4:
                raise ValueError("IFF FORM is missing its type tag")
            form_type = blob[payload_start : payload_start + 4]
            children = parse_iff_nodes(blob, payload_start + 4, payload_end)
            nodes.append(IffNode(tag, form_type, b"", children))
        else:
            nodes.append(IffNode(tag, None, blob[payload_start:payload_end], []))
        cursor = payload_end
    if cursor != end:
        raise ValueError(f"IFF parent has {end - cursor} trailing bytes")
    return nodes


def find_forms(node: IffNode, form_type: bytes) -> Iterable[IffNode]:
    if node.tag == FORM and node.form_type == form_type:
        yield node
    for child in node.children:
        yield from find_forms(child, form_type)


def find_chunks(node: IffNode, tag: bytes) -> Iterable[IffNode]:
    if node.tag == tag and node.form_type is None:
        yield node
    for child in node.children:
        yield from find_chunks(child, tag)


def _first_chunk(node: IffNode, tag: bytes, *, size: int | None = None) -> IffNode | None:
    for candidate in find_chunks(node, tag):
        if size is None or len(candidate.data) == size:
            return candidate
    return None


def _uv_offset(bytes_per_vertex: int) -> int:
    offsets = {32: 24, 36: 28, 40: 24, 44: 28, 48: 24, 52: 28, 56: 24, 60: 28, 64: 24, 68: 28, 72: 24}
    try:
        return offsets[bytes_per_vertex]
    except KeyError as exc:
        raise ValueError(f"unsupported SWG MSH vertex size: {bytes_per_vertex} bytes") from exc


def parse_static_mesh(blob: bytes) -> list[MeshSubmesh]:
    roots = parse_iff_nodes(blob)
    if not roots or roots[0].tag != FORM or roots[0].form_type != b"MESH":
        raise ValueError("asset is not a FORM MESH static mesh")

    sps = next(iter(find_forms(roots[0], b"SPS ")), None)
    if sps is None or not sps.children or sps.children[0].tag != FORM:
        raise ValueError("MSH has no SPS version wrapper")

    submeshes: list[MeshSubmesh] = []
    for group in sps.children[0].children:
        if group.tag != FORM:
            continue
        name = _first_chunk(group, b"NAME")
        vtxa = next(iter(find_forms(group, b"VTXA")), None)
        indx = _first_chunk(group, b"INDX")
        info = _first_chunk(vtxa, b"INFO", size=8) if vtxa else None
        vertex_data = _first_chunk(vtxa, b"DATA") if vtxa else None
        if not name or not vtxa or not info or not indx or not vertex_data:
            raise ValueError("MSH shader group is missing NAME, VTXA, DATA, INFO, or INDX")

        shader = name.data.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
        _fvf_codes, num_vertices = struct.unpack_from("<II", info.data)
        if not num_vertices or len(vertex_data.data) % num_vertices:
            raise ValueError("MSH vertex DATA does not divide evenly into vertices")
        bytes_per_vertex = len(vertex_data.data) // num_vertices
        uv_offset = _uv_offset(bytes_per_vertex)

        positions: list[tuple[float, float, float]] = []
        normals: list[tuple[float, float, float]] = []
        uvs: list[tuple[float, float]] = []
        for index in range(num_vertices):
            base = index * bytes_per_vertex
            position = struct.unpack_from("<3f", vertex_data.data, base)
            normal = struct.unpack_from("<3f", vertex_data.data, base + 12)
            uv = struct.unpack_from("<2f", vertex_data.data, base + uv_offset)
            if not all(math.isfinite(value) for value in (*position, *normal, *uv)):
                raise ValueError("MSH contains a non-finite vertex")
            positions.append(position)
            normals.append(normal)
            uvs.append(uv)

        if len(indx.data) < 4:
            raise ValueError("MSH INDX chunk is empty")
        num_indices = struct.unpack_from("<I", indx.data)[0]
        if not num_indices or (len(indx.data) - 4) % num_indices:
            raise ValueError("MSH INDX size does not match its count")
        bytes_per_index = (len(indx.data) - 4) // num_indices
        if bytes_per_index not in (2, 4):
            raise ValueError(f"unsupported SWG MSH index size: {bytes_per_index} bytes")
        fmt = "<H" if bytes_per_index == 2 else "<I"
        indices = [struct.unpack_from(fmt, indx.data, 4 + i * bytes_per_index)[0] for i in range(num_indices)]
        if max(indices, default=0) >= num_vertices:
            raise ValueError("MSH index refers past its vertex array")
        submeshes.append(MeshSubmesh(shader, positions, normals, uvs, indices))

    if not submeshes:
        raise ValueError("MSH contains no shader groups")
    return submeshes


def _align4(data: bytearray) -> None:
    while len(data) % 4:
        data.append(0)


def _append_blob(buffer: bytearray, blob: bytes) -> tuple[int, int]:
    _align4(buffer)
    offset = len(buffer)
    buffer.extend(blob)
    return offset, len(blob)


def _bounds(positions: list[tuple[float, float, float]]) -> tuple[list[float], list[float]]:
    minimum = [min(position[i] for position in positions) for i in range(3)]
    maximum = [max(position[i] for position in positions) for i in range(3)]
    return minimum, maximum


def write_gltf(submeshes: list[MeshSubmesh], output_gltf: Path, output_bin: Path, source: AssetEntry) -> dict:
    buffer = bytearray()
    buffer_views: list[dict] = []
    accessors: list[dict] = []
    meshes: list[dict] = []
    materials: list[dict] = []

    def add_attribute(values: bytes, component_type: int, count: int, accessor_type: str, *, minimum=None, maximum=None) -> int:
        offset, length = _append_blob(buffer, values)
        view_index = len(buffer_views)
        buffer_views.append({"buffer": 0, "byteOffset": offset, "byteLength": length, "target": 34962})
        accessor = {
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if minimum is not None:
            accessor["min"] = minimum
        if maximum is not None:
            accessor["max"] = maximum
        accessors.append(accessor)
        return len(accessors) - 1

    for submesh_index, submesh in enumerate(submeshes):
        position_bytes = b"".join(struct.pack("<3f", *position) for position in submesh.positions)
        normal_bytes = b"".join(struct.pack("<3f", *normal) for normal in submesh.normals)
        uv_bytes = b"".join(struct.pack("<2f", *uv) for uv in submesh.uvs)
        max_index = max(submesh.indices, default=0)
        index_component = 5123 if max_index < 65536 else 5125
        index_format = "<H" if index_component == 5123 else "<I"
        index_bytes = b"".join(struct.pack(index_format, index) for index in submesh.indices)
        minimum, maximum = _bounds(submesh.positions)

        position_accessor = add_attribute(position_bytes, 5126, len(submesh.positions), "VEC3", minimum=minimum, maximum=maximum)
        normal_accessor = add_attribute(normal_bytes, 5126, len(submesh.normals), "VEC3")
        uv_accessor = add_attribute(uv_bytes, 5126, len(submesh.uvs), "VEC2")
        index_offset, index_length = _append_blob(buffer, index_bytes)
        index_view = len(buffer_views)
        buffer_views.append({"buffer": 0, "byteOffset": index_offset, "byteLength": index_length, "target": 34963})
        accessors.append({
            "bufferView": index_view,
            "componentType": index_component,
            "count": len(submesh.indices),
            "type": "SCALAR",
            "min": [0],
            "max": [max_index],
        })
        index_accessor = len(accessors) - 1
        material_index = len(materials)
        materials.append({
            "name": submesh.shader or f"swg-material-{submesh_index}",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.64, 0.60, 0.54, 1.0],
                "metallicFactor": 0.55,
                "roughnessFactor": 0.62,
            },
            "extras": {"swgShader": submesh.shader},
        })
        meshes.append({
            "name": f"swg-submesh-{submesh_index}",
            "primitives": [{
                "attributes": {"POSITION": position_accessor, "NORMAL": normal_accessor, "TEXCOORD_0": uv_accessor},
                "indices": index_accessor,
                "material": material_index,
                "mode": 4,
            }],
        })

    output_gltf.parent.mkdir(parents=True, exist_ok=True)
    output_bin.parent.mkdir(parents=True, exist_ok=True)
    output_bin.write_bytes(buffer)
    document = {
        "asset": {"version": "2.0", "generator": "Far Horizon local SWG MSH converter"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(meshes)))}],
        "nodes": [{"name": mesh["name"], "mesh": index} for index, mesh in enumerate(meshes)],
        "meshes": meshes,
        "materials": materials,
        "buffers": [{"byteLength": len(buffer), "uri": output_bin.name}],
        "bufferViews": buffer_views,
        "accessors": accessors,
        "extras": {
            "sourceArchive": source.archive.name,
            "sourceVirtualPath": source.virtual_path,
            "conversion": "SWG FORM MESH static subset -> glTF 2.0",
            "shaderTextures": "Resolved at runtime through Far Horizon's local SWG material library",
        },
    }
    output_gltf.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    return {"submeshes": len(meshes), "vertices": sum(len(mesh.positions) for mesh in submeshes), "indices": sum(len(mesh.indices) for mesh in submeshes)}


def choose_mesh(entries: Iterable[AssetEntry]) -> AssetEntry | None:
    exact = "appearance/mesh/ins_all_min_moisture_s01_u0_l0.msh"
    exact_matches = sorted((entry for entry in entries if entry.virtual_path == exact), key=lambda entry: entry.archive.name.lower())
    if exact_matches:
        return exact_matches[0]
    candidates = [
        entry
        for entry in entries
        if entry.extension == ".msh"
        and any(term in entry.virtual_path for term in ("moisture", "vapor", "starport", "tato"))
    ]
    return sorted(candidates, key=lambda entry: (0 if "moisture" in entry.virtual_path else 1, entry.virtual_path, entry.archive.name.lower()))[0] if candidates else None


def convert_from_client(source: Path, output_gltf: Path, output_bin: Path) -> tuple[AssetEntry, dict]:
    tre_files = sorted(path for path in source.rglob("*") if path.is_file() and path.suffix.lower() == ".tre")
    inventory, _stats = inventory_from_archives(tre_files)
    return convert_from_inventory(inventory, output_gltf, output_bin)


def convert_from_inventory(entries: Iterable[AssetEntry], output_gltf: Path, output_bin: Path) -> tuple[AssetEntry, dict]:
    entries = list(entries)
    entry = choose_mesh(entries)
    if entry is None:
        raise FileNotFoundError("no reusable Tatooine/moisture/starport .msh candidate found")
    submeshes = parse_static_mesh(decode_tre_entry(entry.archive, entry.metadata))
    summary = write_gltf(submeshes, output_gltf, output_bin, entry)
    return entry, summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract one local SWG static MSH and convert it to glTF.")
    parser.add_argument("--source", "-s", help="Path to your SWG Restoration client folder.")
    parser.add_argument("--output", help="Output .gltf path (defaults to assets/local-swg/mesh/...)")
    args = parser.parse_args()
    roots = candidate_roots(args.source)
    if not roots:
        print("Could not find an SWG Restoration install. Use --source.", file=sys.stderr)
        return 2
    project_root = Path(__file__).resolve().parents[1]
    output_gltf = Path(args.output) if args.output else project_root / "assets/local-swg/mesh/ins_all_min_moisture_s01_u0_l0.gltf"
    output_bin = output_gltf.with_suffix(".bin")
    try:
        entry, summary = convert_from_client(roots[0], output_gltf, output_bin)
    except Exception as exc:
        print(f"Mesh conversion failed: {exc}", file=sys.stderr)
        return 1
    print(f"Converted {entry.archive.name} :: {entry.virtual_path}")
    print(f"glTF: {output_gltf}")
    print(f"Geometry: {summary['submeshes']} submeshes, {summary['vertices']:,} vertices, {summary['indices']:,} indices")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
