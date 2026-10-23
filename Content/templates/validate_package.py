#!/usr/bin/env python3
"""检查 Content/core_chinese_v1 占位包的形状。不代替上架审核。"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "core_chinese_v1"
EXPECTED_THEMES = {"动物世界", "家庭生活", "自然世界"}


def load(name: str):
    path = ROOT / name
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    errors: list[str] = []
    manifest = load("manifest.json")
    themes = load("themes.json")
    courses = load("courses.json")
    hanzi = load("hanzi.json")
    links = load("course_hanzi.json")
    exercises = load("exercises_placeholder.json")

    if manifest.get("productLine") != "shizi_forest":
        errors.append("productLine 必须是 shizi_forest")
    if manifest.get("remoteUpdate", {}).get("enabled") is not False:
        errors.append("V1.0 远程更新必须是关闭")
    titles = {item["title"] for item in themes}
    if titles != EXPECTED_THEMES:
        errors.append(f"主题名称应为 {EXPECTED_THEMES}，实际 {titles}")
    if len(themes) != 3:
        errors.append("首发主题应为 3 个")
    if len(courses) != manifest["plannedCourseCount"]:
        errors.append("课程数量和 manifest.plannedCourseCount 不一致")
    if len(courses) != 12:
        errors.append("骨架应有 12 节课占位")
    if len(hanzi) != manifest["sampleHanziCount"]:
        errors.append("样例字数量和 manifest.sampleHanziCount 不一致")
    if not 80 <= manifest["plannedHanziCount"] <= 100:
        errors.append("计划字数应在 80～100")
    if exercises.get("implemented") is not True:
        errors.append("三种核心题型应标成已实现")
    if manifest.get("demoAssets") is not True:
        errors.append("演示占位资源必须在 manifest.demoAssets 标明")

    hanzi_ids = {item["id"] for item in hanzi}
    by_theme: dict[str, int] = {}
    for course in courses:
        by_theme[course["themeId"]] = by_theme.get(course["themeId"], 0) + 1
        published = course["status"] == "published"
        if published and not course["hanziIds"]:
            errors.append(f"{course['id']} 没有汉字，不能标成 published")
        if course["hanziIds"] and not published:
            errors.append(f"{course['id']} 已经有样例字，演示包应标成 published")
        for hanzi_id in course["hanziIds"]:
            if hanzi_id not in hanzi_ids:
                errors.append(f"{course['id']} 引用了不存在的 {hanzi_id}")
        linked = [item["hanziId"] for item in links if item["courseId"] == course["id"]]
        if set(linked) != set(course["hanziIds"]):
            errors.append(f"{course['id']} 的 course_hanzi 和 hanziIds 不一致")
    for theme in themes:
        if by_theme.get(theme["id"], 0) != 4:
            errors.append(f"{theme['title']} 应有 4 节课占位")
        if theme["title"] not in EXPECTED_THEMES:
            errors.append(f"意外主题 {theme['title']}")

    glyphs = [item.get("character") for item in hanzi]
    if len(glyphs) != len(set(glyphs)):
        errors.append("汉字字形有重复，家庭试用包里每个字只出现一次")
    if not 80 <= len(hanzi) <= 100:
        errors.append(f"家庭试用字数应在 80～100，实际 {len(hanzi)}")

    required = ["id", "character", "pinyin", "definition", "audioAssetId", "imageAssetId"]
    for item in hanzi:
        for key in required:
            if not item.get(key):
                errors.append(f"{item.get('id')} 缺少 {key}")
        image = ROOT / f"{item['imageAssetId']}.png"
        audio = ROOT / f"{item['audioAssetId']}.wav"
        if item.get("isPublished") is not True:
            errors.append(f"{item['id']} 演示包里的样例字应为 isPublished")
        if not image.exists():
            errors.append(f"{item['id']} 缺少演示图 {image.name}")
        if not audio.exists():
            errors.append(f"{item['id']} 缺少演示音频 {audio.name}")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"OK {ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
