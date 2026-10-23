#!/usr/bin/env python3
"""把 Excel 另存的 CSV 转成识字森林运行时 JSON。

约定见同目录 README.md。只做表格到 JSON 的形状转换，不检查插画和录音是否真的存在。
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

BOOL_COLUMNS = {"isAvailable", "isPublished", "isReview"}
INT_COLUMNS = {
    "sortOrder",
    "contentVersion",
    "minRecommendedAge",
    "maxRecommendedAge",
    "difficulty",
    "strokeCount",
}
LIST_COLUMNS = {
    "learningObjectives",
    "contentTypes",
    "tags",
    "wordExamples",
    "sentenceExamples",
    "relatedHanziIds",
    "hanziIds",
    "exerciseTypes",
}
NULLABLE_STRINGS = {"description", "strokeDataId"}

FILES = {
    "themes.csv": "themes.json",
    "courses.csv": "courses.json",
    "hanzi.csv": "hanzi.json",
    "course_hanzi.csv": "course_hanzi.json",
}


def parse_bool(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"true", "1", "yes", "y", "是"}:
        return True
    if normalized in {"false", "0", "no", "n", "否"}:
        return False
    raise ValueError(f"无法识别的布尔值：{value}")


def parse_cell(column: str, raw: str):
    value = raw.strip()
    if column in LIST_COLUMNS:
        if not value:
            return []
        return [part.strip() for part in value.split("|") if part.strip()]
    if column in BOOL_COLUMNS:
        if not value:
            return False
        return parse_bool(value)
    if column in INT_COLUMNS:
        if not value:
            return None
        return int(value)
    if column in NULLABLE_STRINGS and not value:
        return None
    return value


def convert_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"{path.name} 没有表头")
        rows = []
        for line_number, row in enumerate(reader, start=2):
            if all(not (cell or "").strip() for cell in row.values()):
                continue
            parsed = {}
            for column in reader.fieldnames:
                try:
                    parsed[column] = parse_cell(column, row.get(column) or "")
                except ValueError as error:
                    raise ValueError(f"{path.name} 第 {line_number} 行，列 {column}：{error}") from error
            rows.append(parsed)
        return rows


def main() -> int:
    if len(sys.argv) != 3:
        print("用法: python3 export_csv_to_json.py <csv目录> <输出目录>", file=sys.stderr)
        return 1
    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    for csv_name, json_name in FILES.items():
        csv_path = source / csv_name
        if not csv_path.exists():
            print(f"跳过，没有 {csv_name}")
            continue
        rows = convert_csv(csv_path)
        destination = output / json_name
        destination.write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"{csv_name} -> {destination} ({len(rows)} 行)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
