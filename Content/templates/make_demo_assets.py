#!/usr/bin/env python3
"""生成 Sprint 3 演示用的色块图和短提示音，并标出可以进正式练习的样例课。

这些不是正式插画，也不是标准普通话。正式资源仍以 Excel/CSV → JSON 管线替换同名 assetId。
"""

from __future__ import annotations

import json
import math
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "core_chinese_v1"

COLORS = [
    (232, 126, 108),
    (240, 180, 72),
    (126, 176, 112),
    (90, 164, 196),
    (168, 132, 196),
    (214, 122, 156),
    (120, 154, 196),
    (196, 148, 96),
    (108, 176, 168),
    (196, 112, 112),
    (154, 176, 88),
    (112, 140, 196),
    (196, 168, 120),
    (140, 120, 176),
    (96, 168, 140),
    (186, 130, 96),
]


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, size: int, rgb, shape: int) -> None:
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            raw.extend(pixel(x, y, size, rgb, shape))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def pixel(x: int, y: int, size: int, rgb: tuple[int, int, int], shape: int) -> tuple[int, int, int]:
    background = (255, 246, 232)
    cx = (size - 1) / 2
    cy = (size - 1) / 2
    dx = x - cx
    dy = y - cy
    inside = False
    if shape == 0:
        inside = dx * dx + dy * dy <= (size * 0.32) ** 2
    elif shape == 1:
        inside = abs(dx) <= size * 0.28 and abs(dy) <= size * 0.28
    elif shape == 2:
        inside = abs(dx) / (size * 0.34) + abs(dy + size * 0.08) / (size * 0.36) <= 1
    else:
        inside = abs(dx) + abs(dy) <= size * 0.34
    return rgb if inside else background


def write_wav(path: Path, frequency: float) -> None:
    framerate = 22050
    count = int(framerate * 0.35)
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(framerate)
        frames = bytearray()
        for index in range(count):
            envelope = min(1.0, index / 180, (count - index) / 180)
            sample = int(5000 * envelope * math.sin(2 * math.pi * frequency * index / framerate))
            frames += struct.pack("<h", sample)
        handle.writeframes(frames)


def main() -> None:
    hanzi = json.loads((ROOT / "hanzi.json").read_text(encoding="utf-8"))
    courses = json.loads((ROOT / "courses.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    exercises = json.loads((ROOT / "exercises_placeholder.json").read_text(encoding="utf-8"))

    for index, item in enumerate(hanzi):
        write_png(ROOT / f"{item['imageAssetId']}.png", 256, COLORS[index % len(COLORS)], index % 4)
        write_wav(ROOT / f"{item['audioAssetId']}.wav", 280 + index * 28)
        item["isPublished"] = True

    ready = {item["id"] for item in hanzi}
    for course in courses:
        ids = course["hanziIds"]
        if ids and set(ids) <= ready:
            course["status"] = "published"
        else:
            course["status"] = "planned" if not ids else course["status"]

    manifest["demoAssets"] = True
    manifest["assetsManifestVersion"] = 2
    manifest["notes"] = (
        "样例包。有汉字的课带演示色块图和短提示音，并标成 published，方便把三种练习跑通。"
        "这些不是正式插画和标准普通话。空课仍然是计划中，不能进正式学习。"
        "远程更新只保留字段，V1.0 不下载。"
    )
    exercises["implemented"] = True
    exercises["todo"] = "三种核心题型已在 App 里实现。组词、形近字不在 V1.0。图和录音仍是演示占位。"

    (ROOT / "hanzi.json").write_text(json.dumps(hanzi, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "courses.json").write_text(json.dumps(courses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "exercises_placeholder.json").write_text(json.dumps(exercises, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"demo assets for {len(hanzi)} hanzi in {ROOT}")


if __name__ == "__main__":
    main()
