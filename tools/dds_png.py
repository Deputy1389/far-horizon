from __future__ import annotations

import binascii
import struct
import zlib
from pathlib import Path


class DDSDecodeError(ValueError):
    pass


DDSD_PITCH = 0x00000008
DDSD_LINEARSIZE = 0x00080000
DDPF_ALPHAPIXELS = 0x00000001
DDPF_FOURCC = 0x00000004
DDPF_RGB = 0x00000040


def _rgb565(value: int) -> tuple[int, int, int]:
    r = (value >> 11) & 0x1F
    g = (value >> 5) & 0x3F
    b = value & 0x1F
    return ((r * 255 + 15) // 31, (g * 255 + 31) // 63, (b * 255 + 15) // 31)


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], wa: int, wb: int, div: int) -> tuple[int, int, int]:
    return tuple((a[i] * wa + b[i] * wb) // div for i in range(3))


def _color_palette(block: bytes, dxt1_alpha: bool) -> tuple[list[tuple[int, int, int, int]], int]:
    c0, c1 = struct.unpack_from("<HH", block, 0)
    rgb0 = _rgb565(c0)
    rgb1 = _rgb565(c1)
    palette: list[tuple[int, int, int, int]] = [
        (*rgb0, 255),
        (*rgb1, 255),
    ]
    if c0 > c1 or not dxt1_alpha:
        palette.append((*_mix(rgb0, rgb1, 2, 1, 3), 255))
        palette.append((*_mix(rgb0, rgb1, 1, 2, 3), 255))
    else:
        palette.append((*_mix(rgb0, rgb1, 1, 1, 2), 255))
        palette.append((0, 0, 0, 0))
    indices = struct.unpack_from("<I", block, 4)[0]
    return palette, indices


def _write_block(
    pixels: bytearray,
    width: int,
    height: int,
    block_x: int,
    block_y: int,
    colors: list[tuple[int, int, int, int]],
    color_indices: int,
    alphas: list[int] | None = None,
) -> None:
    for py in range(4):
        y = block_y * 4 + py
        if y >= height:
            continue
        for px in range(4):
            x = block_x * 4 + px
            if x >= width:
                continue
            pixel_index = py * 4 + px
            color = colors[(color_indices >> (2 * pixel_index)) & 0x3]
            alpha = color[3] if alphas is None else alphas[pixel_index]
            out = (y * width + x) * 4
            pixels[out : out + 4] = bytes((color[0], color[1], color[2], alpha))


def _decode_dxt(data: bytes, width: int, height: int, fourcc: bytes) -> bytes:
    blocks_x = max(1, (width + 3) // 4)
    blocks_y = max(1, (height + 3) // 4)
    pixels = bytearray(width * height * 4)
    offset = 128

    dxt1 = fourcc == b"DXT1"
    dxt3 = fourcc in (b"DXT2", b"DXT3")
    dxt5 = fourcc in (b"DXT4", b"DXT5")
    if not (dxt1 or dxt3 or dxt5):
        raise DDSDecodeError(f"unsupported compressed DDS format {fourcc!r}")

    block_size = 8 if dxt1 else 16
    required = offset + blocks_x * blocks_y * block_size
    if len(data) < required:
        raise DDSDecodeError(f"DDS payload is short: need {required} bytes, got {len(data)}")

    for by in range(blocks_y):
        for bx in range(blocks_x):
            block = data[offset : offset + block_size]
            offset += block_size

            if dxt1:
                colors, color_indices = _color_palette(block, True)
                _write_block(pixels, width, height, bx, by, colors, color_indices)
                continue

            color_block = block[8:16]
            colors, color_indices = _color_palette(color_block, False)

            if dxt3:
                alpha_bits = int.from_bytes(block[:8], "little")
                alphas = [((alpha_bits >> (4 * i)) & 0xF) * 17 for i in range(16)]
            else:
                a0, a1 = block[0], block[1]
                palette = [a0, a1]
                if a0 > a1:
                    palette.extend(((a0 * (7 - i) + a1 * i) // 7) for i in range(1, 7))
                else:
                    palette.extend(((a0 * (5 - i) + a1 * i) // 5) for i in range(1, 5))
                    palette.extend([0, 255])
                alpha_indices = int.from_bytes(block[2:8], "little")
                alphas = [palette[(alpha_indices >> (3 * i)) & 0x7] for i in range(16)]

            _write_block(pixels, width, height, bx, by, colors, color_indices, alphas)

    return bytes(pixels)


def _channel(value: int, mask: int, default: int = 0) -> int:
    if mask == 0:
        return default
    shift = (mask & -mask).bit_length() - 1
    field = (value & mask) >> shift
    bits = (mask >> shift).bit_length()
    maximum = (1 << bits) - 1
    return (field * 255 + maximum // 2) // maximum if maximum else default


def _decode_rgb(data: bytes, width: int, height: int, flags: int, pitch: int) -> bytes:
    pf_flags = struct.unpack_from("<I", data, 80)[0]
    bit_count = struct.unpack_from("<I", data, 88)[0]
    r_mask, g_mask, b_mask, a_mask = struct.unpack_from("<4I", data, 92)
    if not (pf_flags & DDPF_RGB) or bit_count not in (16, 24, 32):
        raise DDSDecodeError(f"unsupported uncompressed DDS format, flags={pf_flags:#x}, bits={bit_count}")

    bytes_per_pixel = bit_count // 8
    tight_pitch = width * bytes_per_pixel
    row_pitch = pitch if (flags & DDSD_PITCH and pitch >= tight_pitch) else tight_pitch
    required = 128 + row_pitch * height
    if len(data) < required:
        raise DDSDecodeError(f"DDS payload is short: need {required} bytes, got {len(data)}")

    pixels = bytearray(width * height * 4)
    for y in range(height):
        row = 128 + y * row_pitch
        for x in range(width):
            start = row + x * bytes_per_pixel
            value = int.from_bytes(data[start : start + bytes_per_pixel], "little")
            out = (y * width + x) * 4
            pixels[out : out + 4] = bytes(
                (
                    _channel(value, r_mask),
                    _channel(value, g_mask),
                    _channel(value, b_mask),
                    _channel(value, a_mask, 255) if (pf_flags & DDPF_ALPHAPIXELS) else 255,
                )
            )
    return bytes(pixels)


def decode_dds_rgba(data: bytes) -> tuple[int, int, bytes]:
    if len(data) < 128 or data[:4] != b"DDS ":
        raise DDSDecodeError("not a DDS file")
    if struct.unpack_from("<I", data, 4)[0] != 124:
        raise DDSDecodeError("unsupported DDS header size")

    flags = struct.unpack_from("<I", data, 8)[0]
    height = struct.unpack_from("<I", data, 12)[0]
    width = struct.unpack_from("<I", data, 16)[0]
    pitch_or_linear = struct.unpack_from("<I", data, 20)[0]
    pf_flags = struct.unpack_from("<I", data, 80)[0]
    fourcc = data[84:88]

    if width <= 0 or height <= 0:
        raise DDSDecodeError("invalid DDS dimensions")
    if fourcc == b"DX10":
        raise DDSDecodeError("DX10 DDS is not used by the current SWG pipeline")

    if pf_flags & DDPF_FOURCC:
        rgba = _decode_dxt(data, width, height, fourcc)
    else:
        rgba = _decode_rgb(data, width, height, flags, pitch_or_linear)
    return width, height, rgba


def _png_chunk(name: bytes, payload: bytes) -> bytes:
    body = name + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", binascii.crc32(body) & 0xFFFFFFFF)


def encode_png_rgba(width: int, height: int, rgba: bytes) -> bytes:
    if len(rgba) != width * height * 4:
        raise ValueError("RGBA buffer size does not match dimensions")
    stride = width * 4
    scanlines = b"".join(b"\x00" + rgba[y * stride : (y + 1) * stride] for y in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + _png_chunk(b"IDAT", zlib.compress(scanlines, 6))
        + _png_chunk(b"IEND", b"")
    )


def dds_to_png_bytes(data: bytes) -> bytes:
    width, height, rgba = decode_dds_rgba(data)
    return encode_png_rgba(width, height, rgba)


def dds_to_png_file(source: Path, destination: Path) -> None:
    png = dds_to_png_bytes(source.read_bytes())
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(png)
