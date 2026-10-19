# 内容模板：Excel → JSON

识字森林的编辑源是表格，运行时读 JSON。V1.0 不从网络拉课。

## 怎么用

1. 用 Excel 或 Numbers 打开同目录的 CSV（UTF-8，带 BOM，方便 Excel 打开中文）。
2. 表头不要改名。列表用 `|` 分开，例如 `hanzi|image|audio`。
3. 布尔写 `true` / `false`（也可以写 `是` / `否`）。空的可选数字留空。
4. 另存为 CSV UTF-8。
5. 导出：

```bash
python3 Content/templates/export_csv_to_json.py <csv目录> <输出目录>
```

会生成 `themes.json`、`courses.json`、`hanzi.json`、`course_hanzi.json`。核对后放进 `Content/core_chinese_v1/`，并改 `manifest.json` 里的版本号。

检查占位包：

```bash
python3 Content/templates/validate_package.py
```

## 表和字段

| 文件 | 运行时 | 说明 |
|---|---|---|
| `themes.csv` | `themes.json` | 主题。`sortOrder` 决定顺序，不靠文件顺序 |
| `courses.csv` | `courses.json` | 课程。`status` 用 `published` / `placeholder` / `planned` |
| `hanzi.csv` | `hanzi.json` | 汉字。`id` 稳定，不要用行号 |
| `course_hanzi.csv` | `course_hanzi.json` | 课和字的关联，`courseId + hanziId` 唯一 |

`published` 只给已经有图、标准普通话录音、字义和至少一种已实现练习的课。缺任何一项就不要标成可学。

字的 `id` 一旦发给孩子用过，就不要改。插画和录音文件以后按 `imageAssetId`、`audioAssetId` 放进包，这一步还没做。

`manifest.json` 不从 CSV 来。远程更新字段 `remoteUpdate.enabled` 在 V1.0 保持 `false`。
