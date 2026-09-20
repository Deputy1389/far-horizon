"""Small pure-Python Twofish ECB decryptor used for local SWG Restoration files.

The round structure and lookup tables match the public-domain Crypto++ Twofish
implementation shipped in the open SWG source tree. Restoration uses the
128-bit form through ``Crypto::TwofishDecryptor``.
"""

from __future__ import annotations

import struct

_MASK32 = 0xFFFFFFFF
_RS_POLY = 0x14D
_GF_POLY = 0x169

_Q_HEX = (
    "A967B3E804FDA3769A928078E4DDD1380DC6359818F7EC6C43753726FA139448"
    "F2D08B308454DF23195B3D59F3AEA2826301832ED9519B7CA6EBA5BE160CE361"
    "C08C3AF5732C250BBB4E896B536AB4F1E1E6BD45E2F4B666CC950356D41C1ED7"
    "FBC38EB5E9CFBFBAEA7739AF33C96271817909AD24CDF9D8E5C5B94D440886E7"
    "A11DAAED0670B2D2417BA01131C2279020F660FF965CB1AB9E9C521B5F930AEF"
    "918549EE2D4F8F3B47876D46D63E69642ACECB2FFC97057AAC7FD51A4B0EA75A"
    "28143F29883C4C02B8DAB017551F8A7D57C78D74B7C49F727E15221258079934"
    "6E50DE6865BCDBF8C8A82B40DCFE32A4CA1021F0D35D0F006F9D36424A5EC1E0"
    "75F3C6F4DB7BFBC84AD3E66B457DE84BD632D8FD3771F1E1300FF81B87FA063F"
    "5EBAAE5B8A00BC9D6DC1B10E805DD2D5A0840714B5902CA3B2734C5492743651"
    "38B0BD5AFC6062966C42F7107C28278C13959CC724463B70CAE385CB11D093B8"
    "A68320FF9F77C3CC036F08BF40E72BE2790CAA82413AEAB9E49AA4977EDA7A17"
    "6694A11D3DF0DEB30B72A71CEFD1533E8F33265FEC762A498188EE21C41AEBD9"
    "C53999CDAD318B011823DD1F4E2DF9484FF2658E785C58198DE59857677F0564"
    "AF63B6FEF5B73CA5CEE96844E04D4369292EAC1559A80A9E6E47DF34356ACFDC"
    "22C9C09B89D4EDAB12A20D52BB022FA9D7611EB45004F6C2162586565509BE91"
)
_Q = (bytes.fromhex(_Q_HEX[: 2 * 256]), bytes.fromhex(_Q_HEX[2 * 256 :]))


def _rol32(value: int, count: int) -> int:
    value &= _MASK32
    return ((value << count) | (value >> (32 - count))) & _MASK32


def _ror32(value: int, count: int) -> int:
    value &= _MASK32
    return ((value >> count) | (value << (32 - count))) & _MASK32


def _gf_multiply(left: int, right: int) -> int:
    result = 0
    for _ in range(8):
        if right & 1:
            result ^= left
        left = ((left << 1) & 0xFF) ^ (_GF_POLY & 0xFF if left & 0x80 else 0)
        right >>= 1
    return result


def _mds_tables() -> tuple[tuple[int, ...], ...]:
    # Crypto++ stores the MDS transform after the q permutation in four
    # lookup tables. Generating the 4 KiB table keeps the implementation
    # auditable while avoiding another opaque copied table.
    matrix = (
        (0x01, 0x5B, 0xEF, 0xEF),
        (0xEF, 0xEF, 0x5B, 0x01),
        (0x5B, 0xEF, 0x01, 0xEF),
        (0x5B, 0x01, 0xEF, 0x5B),
    )
    tables = []
    for row, coefficients in enumerate(matrix):
        permutation = _Q[1 if row in (0, 2) else 0]
        tables.append(
            tuple(
                sum(_gf_multiply(permutation[index], coefficient) << (8 * column)
                    for column, coefficient in enumerate(coefficients))
                for index in range(256)
            )
        )
    return tuple(tables)


_MDS = _mds_tables()


def _mod_rs(value: int) -> int:
    c2 = (value << 1) ^ (_RS_POLY if value & 0x80 else 0)
    c1 = c2 ^ (value >> 1) ^ (_RS_POLY >> 1 if value & 1 else 0)
    return (value | (c1 << 8) | (c2 << 16) | (c1 << 24)) & _MASK32


def _reed_solomon(high: int, low: int) -> int:
    for _ in range(8):
        high = _mod_rs(high >> 24) ^ ((high << 8) & _MASK32) ^ (low >> 24)
        low = (low << 8) & _MASK32
    return high & _MASK32


def _q_word(a: int, b: int, c: int, d: int, value: int) -> int:
    return (
        _Q[a][value & 0xFF]
        | (_Q[b][(value >> 8) & 0xFF] << 8)
        | (_Q[c][(value >> 16) & 0xFF] << 16)
        | (_Q[d][(value >> 24) & 0xFF] << 24)
    )


def _h0(value: int, key_words: list[int], key_words_count: int) -> int:
    value = (value | (value << 8) | (value << 16) | (value << 24)) & _MASK32
    if key_words_count == 4:
        value = _q_word(1, 0, 0, 1, value) ^ key_words[6]
    if key_words_count >= 3:
        value = _q_word(1, 1, 0, 0, value) ^ key_words[4]
    if key_words_count >= 2:
        value = _q_word(0, 1, 0, 1, value) ^ key_words[2]
        value = _q_word(0, 0, 1, 1, value) ^ key_words[0]
    return value & _MASK32


def _h(value: int, key_words: list[int], key_words_count: int) -> int:
    value = _h0(value, key_words, key_words_count)
    return (
        _MDS[0][value & 0xFF]
        ^ _MDS[1][(value >> 8) & 0xFF]
        ^ _MDS[2][(value >> 16) & 0xFF]
        ^ _MDS[3][(value >> 24) & 0xFF]
    ) & _MASK32


def _schedule(user_key: bytes) -> tuple[list[int], tuple[tuple[int, ...], ...]]:
    if len(user_key) not in (16, 24, 32):
        raise ValueError("Twofish keys must be 16, 24, or 32 bytes")

    key_words = list(struct.unpack(f"<{len(user_key) // 4}I", user_key))
    key_words_count = len(user_key) // 8
    round_keys = [0] * 40
    for index in range(0, 40, 2):
        a = _h(index, key_words, key_words_count)
        b = _rol32(_h(index + 1, key_words[1:], key_words_count), 8)
        round_keys[index] = (a + b) & _MASK32
        round_keys[index + 1] = _rol32(a + 2 * b, 9)

    s_vector = [0] * (2 * key_words_count)
    for index in range(key_words_count):
        s_vector[2 * (key_words_count - index - 1)] = _reed_solomon(
            key_words[2 * index + 1], key_words[2 * index]
        )

    s_box = [[0] * 256 for _ in range(4)]
    for index in range(256):
        value = _h0(index, s_vector, key_words_count)
        for row in range(4):
            s_box[row][index] = _MDS[row][(value >> (8 * row)) & 0xFF]
    return round_keys, tuple(tuple(row) for row in s_box)


def decrypt_twofish_ecb(ciphertext: bytes, key: bytes) -> bytes:
    """Decrypt complete Twofish blocks using the SWG client convention."""

    if len(ciphertext) % 16:
        raise ValueError("Twofish ECB input must be a multiple of 16 bytes")
    round_keys, s_box = _schedule(key)

    def g1(value: int) -> int:
        return (
            s_box[0][value & 0xFF]
            ^ s_box[1][(value >> 8) & 0xFF]
            ^ s_box[2][(value >> 16) & 0xFF]
            ^ s_box[3][(value >> 24) & 0xFF]
        ) & _MASK32

    def g2(value: int) -> int:
        return (
            s_box[0][(value >> 24) & 0xFF]
            ^ s_box[1][value & 0xFF]
            ^ s_box[2][(value >> 8) & 0xFF]
            ^ s_box[3][(value >> 16) & 0xFF]
        ) & _MASK32

    output = bytearray()
    for offset in range(0, len(ciphertext), 16):
        c, d, a, b = struct.unpack_from("<4I", ciphertext, offset)
        c ^= round_keys[4]
        d ^= round_keys[5]
        a ^= round_keys[6]
        b ^= round_keys[7]

        for cycle in range(7, -1, -1):
            x = g1(c)
            y = g2(d)
            x = (x + y) & _MASK32
            y = (y + x) & _MASK32
            b = _ror32(b ^ ((y + round_keys[8 + 2 * (2 * cycle + 1) + 1]) & _MASK32), 1)
            a = _rol32(a, 1) ^ ((x + round_keys[8 + 2 * (2 * cycle + 1)]) & _MASK32)

            x = g1(a)
            y = g2(b)
            x = (x + y) & _MASK32
            y = (y + x) & _MASK32
            d = _ror32(d ^ ((y + round_keys[8 + 2 * (2 * cycle) + 1]) & _MASK32), 1)
            c = _rol32(c, 1) ^ ((x + round_keys[8 + 2 * (2 * cycle)]) & _MASK32)

        output.extend(
            struct.pack(
                "<4I",
                (a ^ round_keys[0]) & _MASK32,
                (b ^ round_keys[1]) & _MASK32,
                (c ^ round_keys[2]) & _MASK32,
                (d ^ round_keys[3]) & _MASK32,
            )
        )
    return bytes(output)


def encrypt_twofish_ecb(plaintext: bytes, key: bytes) -> bytes:
    """Encrypt complete Twofish blocks for decoder fixtures and round trips."""

    if len(plaintext) % 16:
        raise ValueError("Twofish ECB input must be a multiple of 16 bytes")
    round_keys, s_box = _schedule(key)

    def g1(value: int) -> int:
        return (
            s_box[0][value & 0xFF]
            ^ s_box[1][(value >> 8) & 0xFF]
            ^ s_box[2][(value >> 16) & 0xFF]
            ^ s_box[3][(value >> 24) & 0xFF]
        ) & _MASK32

    def g2(value: int) -> int:
        return (
            s_box[0][(value >> 24) & 0xFF]
            ^ s_box[1][value & 0xFF]
            ^ s_box[2][(value >> 8) & 0xFF]
            ^ s_box[3][(value >> 16) & 0xFF]
        ) & _MASK32

    output = bytearray()
    for offset in range(0, len(plaintext), 16):
        a, b, c, d = struct.unpack_from("<4I", plaintext, offset)
        a ^= round_keys[0]
        b ^= round_keys[1]
        c ^= round_keys[2]
        d ^= round_keys[3]

        for cycle in range(8):
            x = g1(a)
            y = g2(b)
            x = (x + y) & _MASK32
            y = (y + x + round_keys[8 + 4 * cycle + 1]) & _MASK32
            c = _ror32(c ^ ((x + round_keys[8 + 4 * cycle]) & _MASK32), 1)
            d = (_rol32(d, 1) ^ y) & _MASK32

            x = g1(c)
            y = g2(d)
            x = (x + y) & _MASK32
            y = (y + x + round_keys[8 + 4 * cycle + 3]) & _MASK32
            a = _ror32(a ^ ((x + round_keys[8 + 4 * cycle + 2]) & _MASK32), 1)
            b = (_rol32(b, 1) ^ y) & _MASK32

        output.extend(
            struct.pack(
                "<4I",
                (c ^ round_keys[4]) & _MASK32,
                (d ^ round_keys[5]) & _MASK32,
                (a ^ round_keys[6]) & _MASK32,
                (b ^ round_keys[7]) & _MASK32,
            )
        )
    return bytes(output)
