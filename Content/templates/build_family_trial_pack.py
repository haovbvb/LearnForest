#!/usr/bin/env python3
"""把家庭试用课程包补到 12 节课、约 90 个字。

已有汉字 id 保持不变。新字使用 hanzi_<slug> / image_<slug> / audio_<slug>。
图和声音仍由 make_demo_assets.py 生成，正式资源以后按同一 id 替换。
"""

from __future__ import annotations

import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "core_chinese_v1"
EXERCISES = [
    "listen_and_select_image",
    "character_to_image",
    "character_image_matching",
]


def hanzi(slug, character, pinyin, definition, strokes, tag, difficulty=1, words=(), sentence=""):
    return {
        "id": f"hanzi_{slug}",
        "character": character,
        "pinyin": pinyin,
        "definition": definition,
        "audioAssetId": f"audio_{slug}",
        "imageAssetId": f"image_{slug}",
        "difficulty": difficulty,
        "tags": [tag],
        "contentVersion": 1,
        "isPublished": True,
        "strokeCount": strokes,
        "strokeDataId": None,
        "wordExamples": list(words),
        "sentenceExamples": [sentence] if sentence else [],
        "relatedHanziIds": None,
    }


NEW = [
    hanzi("horse", "马", "mǎ", "会跑的大动物，可以骑。", 3, "animal", words=("小马", "马车"), sentence="小马在草地上跑。"),
    hanzi("cow", "牛", "niú", "会耕田的大动物，会哞哞叫。", 4, "animal", words=("水牛", "牛奶"), sentence="牛在田边吃草。"),
    hanzi("sheep", "羊", "yáng", "身上有毛，常常成群走。", 6, "animal", words=("小羊", "羊毛"), sentence="小羊跟着妈妈。"),
    hanzi("rabbit", "兔", "tù", "耳朵长，一下一下地跳。", 8, "animal", words=("小兔", "白兔"), sentence="小兔在菜园里跳。"),
    hanzi("tiger", "虎", "hǔ", "额头有花纹的大猫。", 8, "animal", 2, ("老虎", "虎仔"), "老虎住在林子里。"),
    hanzi("bear", "熊", "xióng", "身体壮，很喜欢蜂蜜。", 14, "animal", 2, ("小熊", "黑熊"), "小熊爬上树找蜂蜜。"),
    hanzi("wolf", "狼", "láng", "样子像狗，常常成群。", 10, "animal", 2, ("狼群",), "狼在夜里叫。"),
    hanzi("monkey", "猴", "hóu", "会爬树，动作很快。", 12, "animal", words=("猴子", "小猴"), sentence="猴子在树上荡来荡去。"),
    hanzi("elephant", "象", "xiàng", "鼻子长，耳朵也很大。", 12, "animal", 2, ("大象",), "大象用鼻子喝水。"),
    hanzi("deer", "鹿", "lù", "腿长，跑起来很快。", 11, "animal", 2, ("小鹿", "梅花鹿"), "小鹿在林间走路。"),
    hanzi("snake", "蛇", "shé", "没有脚，身体长长的。", 11, "animal", 2, ("长蛇",), "蛇慢慢爬过草地。"),
    hanzi("chicken", "鸡", "jī", "家里常见，清早会叫。", 7, "animal", words=("小鸡", "公鸡"), sentence="小鸡跟着母鸡找虫。"),
    hanzi("duck", "鸭", "yā", "嘴巴扁扁的，喜欢水。", 16, "animal", words=("小鸭", "鸭子"), sentence="小鸭在池塘里游。"),
    hanzi("goose", "鹅", "é", "脖子长，叫声很响。", 12, "animal", words=("大鹅",), sentence="大鹅摇摇摆摆地走。"),
    hanzi("frog", "蛙", "wā", "会跳，常常待在水边。", 12, "animal", words=("青蛙",), sentence="青蛙坐在荷叶上。"),
    hanzi("bee", "蜂", "fēng", "会飞，忙着在花上采蜜。", 13, "animal", 2, ("蜜蜂",), "蜜蜂飞到花心里。"),
    hanzi("bug", "虫", "chóng", "小小的，种类很多。", 6, "animal", words=("小虫", "虫子"), sentence="小虫爬上叶子。"),
    hanzi("shrimp", "虾", "xiā", "生活在水里，身子会弯。", 9, "animal", 2, ("小虾",), "小虾藏在水草边。"),
    hanzi("fox", "狐", "hú", "尾巴大，耳朵尖尖的。", 8, "animal", 2, ("狐狸",), "狐狸从树后探出头。"),
    hanzi("mouse", "鼠", "shǔ", "个子小，门牙会一直长。", 13, "animal", 2, ("老鼠",), "老鼠悄悄走过。"),
    hanzi("pig", "猪", "zhū", "鼻子圆圆的，常在猪圈里。", 11, "animal", words=("小猪",), sentence="小猪在泥里玩。"),
    hanzi("turtle", "龟", "guī", "背上有壳，走得很慢。", 7, "animal", words=("乌龟",), sentence="乌龟慢慢爬到水边。"),
    hanzi("dragon", "龙", "lóng", "故事里会飞的动物。", 16, "animal", 2, ("长龙",), "故事里的龙在云上飞。"),
    hanzi("lion", "狮", "shī", "头上有一圈毛，叫声大。", 9, "animal", 2, ("狮子",), "狮子站在高高的石头上。"),
    hanzi("eagle", "鹰", "yīng", "翅膀宽，飞得很高。", 18, "animal", 2, ("老鹰",), "老鹰在天上盘旋。"),
    hanzi("grandpa", "爷", "yé", "爸爸的爸爸，常常疼孩子。", 6, "family", words=("爷爷",), sentence="爷爷牵着我的手。"),
    hanzi("grandma", "奶", "nǎi", "爸爸或妈妈的妈妈。", 5, "family", words=("奶奶", "牛奶"), sentence="奶奶在厨房忙。"),
    hanzi("brother", "哥", "gē", "比自己大的男孩。", 10, "family", words=("哥哥",), sentence="哥哥帮我拿书包。"),
    hanzi("sister", "姐", "jiě", "比自己大的女孩。", 8, "family", words=("姐姐",), sentence="姐姐给我读故事。"),
    hanzi("younger_brother", "弟", "dì", "比自己小的男孩。", 7, "family", words=("弟弟",), sentence="弟弟在门口等我。"),
    hanzi("younger_sister", "妹", "mèi", "比自己小的女孩。", 8, "family", words=("妹妹",), sentence="妹妹抱着布娃娃。"),
    hanzi("rice", "米", "mǐ", "做米饭用的一粒一粒。", 6, "family", words=("大米", "米饭"), sentence="锅里的米饭香香的。"),
    hanzi("noodle", "面", "miàn", "可以做成面条。", 9, "family", words=("面条",), sentence="碗里盛着热面条。"),
    hanzi("bowl", "碗", "wǎn", "用来盛饭盛汤。", 13, "family", words=("饭碗",), sentence="我把碗洗干净。"),
    hanzi("cup", "杯", "bēi", "用来喝水。", 8, "family", words=("水杯",), sentence="杯子里有温水。"),
    hanzi("tea", "茶", "chá", "用叶子泡的饮料。", 9, "family", 2, ("茶水", "喝茶"), "爷爷爱喝茶。"),
    hanzi("door", "门", "mén", "进出房间要经过它。", 3, "family", words=("大门", "开门"), sentence="请随手关门。"),
    hanzi("window", "窗", "chuāng", "墙上透进光的地方。", 12, "family", words=("窗户",), sentence="窗户打开了，风进来了。"),
    hanzi("bed", "床", "chuáng", "晚上睡觉的地方。", 7, "family", words=("小床",), sentence="我按时上床睡觉。"),
    hanzi("table", "桌", "zhuō", "可以在上面吃饭、画画。", 10, "family", words=("桌子",), sentence="书放在桌子上。"),
    hanzi("chair", "椅", "yǐ", "坐下来用的。", 12, "family", words=("椅子",), sentence="我把椅子摆好。"),
    hanzi("lamp", "灯", "dēng", "天黑了用来照明。", 6, "family", words=("电灯",), sentence="天黑了，灯亮了。"),
    hanzi("wall", "墙", "qiáng", "房子四周用来挡风。", 14, "family", 2, ("墙壁",), "墙上挂着一幅画。"),
    hanzi("book", "书", "shū", "一页一页，可以读。", 4, "family", words=("书本", "看书"), sentence="我每天看一会儿书。"),
    hanzi("pen", "笔", "bǐ", "用来写字、画画。", 10, "family", words=("铅笔", "毛笔"), sentence="铅笔削好了。"),
    hanzi("paper", "纸", "zhǐ", "写字画画用的。", 7, "family", words=("纸张", "白纸"), sentence="我在白纸上画画。"),
    hanzi("draw", "画", "huà", "用笔把看到的记下来。", 8, "family", words=("画画", "图画"), sentence="我画了一只小鸟。"),
    hanzi("ball", "球", "qiú", "圆圆的，可以拍，也可以踢。", 11, "family", words=("皮球",), sentence="我们在院子里拍球。"),
    hanzi("car", "车", "chē", "有轮子，用来出行。", 4, "family", words=("小车", "开车"), sentence="爸爸开车去买菜。"),
    hanzi("bag", "包", "bāo", "可以装书和用具。", 5, "family", words=("书包",), sentence="书包里有铅笔。"),
    hanzi("sky", "天", "tiān", "头顶上宽宽的一片。", 4, "nature", words=("天空", "白天"), sentence="今天的天空很蓝。"),
    hanzi("cloud", "云", "yún", "天上白白软软的一团。", 4, "nature", words=("白云", "云朵"), sentence="白云慢慢飘过去。"),
    hanzi("star", "星", "xīng", "夜里天上的小亮点。", 9, "nature", words=("星星",), sentence="夜里能看见星星。"),
    hanzi("fire", "火", "huǒ", "会发光发热，要小心。", 4, "nature", 2, ("火焰", "大火"), "火不能随便玩。"),
    hanzi("snow", "雪", "xuě", "天冷时落下的白花。", 11, "nature", words=("下雪", "雪花"), sentence="雪花落在手上。"),
    hanzi("thunder", "雷", "léi", "下雨时很响的声音。", 13, "nature", 2, ("打雷",), "打雷的时候待在屋里。"),
    hanzi("lightning", "电", "diàn", "雷雨里亮亮的一闪。", 5, "nature", 2, ("闪电",), "闪电照亮了夜空。"),
    hanzi("rainbow", "虹", "hóng", "雨后天上的彩色桥。", 9, "nature", 2, ("彩虹",), "雨停后出了彩虹。"),
    hanzi("dew", "露", "lù", "清晨叶子上的小水珠。", 21, "nature", 2, ("露水",), "清晨的叶子上有露水。"),
    hanzi("frost", "霜", "shuāng", "很冷时地上白茫茫的一层。", 17, "nature", 2, ("霜冻",), "清晨地面上有一层霜。"),
    hanzi("flower", "花", "huā", "植物开出的彩色部分。", 7, "nature", words=("花朵", "红花"), sentence="花开了，真好看。"),
    hanzi("grass", "草", "cǎo", "地上矮矮的绿叶子。", 9, "nature", words=("小草", "青草"), sentence="小草从土里钻出来。"),
    hanzi("bamboo", "竹", "zhú", "一节一节，长得高高的。", 6, "nature", words=("竹子",), sentence="竹子在风里轻轻摇。"),
    hanzi("leaf", "叶", "yè", "长在枝上的绿片。", 5, "nature", words=("树叶", "叶子"), sentence="树叶落下来了。"),
    hanzi("fruit", "果", "guǒ", "植物结出来、有的可以吃。", 8, "nature", words=("水果", "果子"), sentence="树上结了果子。"),
    hanzi("tree", "树", "shù", "有树干，也有很多叶子。", 9, "nature", words=("大树", "树苗"), sentence="我们在大树下乘凉。"),
    hanzi("wood", "木", "mù", "树干可以做成木头。", 4, "nature", words=("木头", "木桌"), sentence="这张桌子是木头做的。"),
    hanzi("stone", "石", "shí", "硬硬的，山上常见。", 5, "nature", words=("石头", "石子"), sentence="小石子躺在河边。"),
    hanzi("field", "田", "tián", "种庄稼的一块地。", 5, "nature", words=("水田", "田地"), sentence="田里长着绿苗。"),
    hanzi("soil", "土", "tǔ", "脚下松松的泥土。", 3, "nature", words=("泥土", "土地"), sentence="种子埋进泥土里。"),
    hanzi("river", "河", "hé", "长长的流水。", 8, "nature", words=("小河", "河水"), sentence="小河向远方流去。"),
    hanzi("sea", "海", "hǎi", "很大很宽的水。", 10, "nature", words=("大海",), sentence="大海一眼望不到边。"),
    hanzi("lake", "湖", "hú", "四周是岸的一片水。", 12, "nature", 2, ("湖水",), "湖水静静的。"),
    hanzi("spring", "泉", "quán", "从地下冒出来的水。", 9, "nature", 2, ("泉水",), "泉水清清的。"),
]

COURSE_PLAN = {
    "course_animals_01": {
        "description": "猫、狗、鸟、鱼，还有马、牛、羊、兔。",
        "ids": ["hanzi_cat", "hanzi_dog", "hanzi_bird", "hanzi_fish", "hanzi_horse", "hanzi_cow", "hanzi_sheep", "hanzi_rabbit"],
    },
    "course_animals_02": {
        "description": "从「林」认到虎、熊、狼、猴、象、鹿、蛇。",
        "ids": ["hanzi_forest", "hanzi_tiger", "hanzi_bear", "hanzi_wolf", "hanzi_monkey", "hanzi_elephant", "hanzi_deer", "hanzi_snake"],
    },
    "course_animals_03": {
        "description": "听听鸡、鸭、鹅、蛙、蜂、虫、虾。",
        "ids": ["hanzi_chicken", "hanzi_duck", "hanzi_goose", "hanzi_frog", "hanzi_bee", "hanzi_bug", "hanzi_shrimp"],
    },
    "course_animals_04": {
        "description": "再认狐、鼠、猪、龟、龙、狮、鹰。",
        "ids": ["hanzi_fox", "hanzi_mouse", "hanzi_pig", "hanzi_turtle", "hanzi_dragon", "hanzi_lion", "hanzi_eagle"],
    },
    "course_family_01": {
        "description": "爸、妈、爷、奶、哥、姐、弟、妹。",
        "ids": ["hanzi_ba", "hanzi_ma", "hanzi_grandpa", "hanzi_grandma", "hanzi_brother", "hanzi_sister", "hanzi_younger_brother", "hanzi_younger_sister"],
    },
    "course_family_02": {
        "description": "家、饭、衣，还有米、面、碗、杯、茶。",
        "ids": ["hanzi_home", "hanzi_meal", "hanzi_clothes", "hanzi_rice", "hanzi_noodle", "hanzi_bowl", "hanzi_cup", "hanzi_tea"],
    },
    "course_family_03": {
        "description": "门、窗、床、桌、椅、灯、墙。",
        "ids": ["hanzi_door", "hanzi_window", "hanzi_bed", "hanzi_table", "hanzi_chair", "hanzi_lamp", "hanzi_wall"],
    },
    "course_family_04": {
        "title": "家里的用具",
        "description": "书、笔、纸、画、球、车、包。",
        "ids": ["hanzi_book", "hanzi_pen", "hanzi_paper", "hanzi_draw", "hanzi_ball", "hanzi_car", "hanzi_bag"],
    },
    "course_nature_01": {
        "description": "日、月、山、水，还有天、云、星、火。",
        "ids": ["hanzi_sun", "hanzi_moon", "hanzi_mountain", "hanzi_water", "hanzi_sky", "hanzi_cloud", "hanzi_star", "hanzi_fire"],
    },
    "course_nature_02": {
        "description": "风、雨、雪、雷、电、虹、露、霜。",
        "ids": ["hanzi_wind", "hanzi_rain", "hanzi_snow", "hanzi_thunder", "hanzi_lightning", "hanzi_rainbow", "hanzi_dew", "hanzi_frost"],
    },
    "course_nature_03": {
        "description": "花、草、竹、叶、果、树、木。",
        "ids": ["hanzi_flower", "hanzi_grass", "hanzi_bamboo", "hanzi_leaf", "hanzi_fruit", "hanzi_tree", "hanzi_wood"],
    },
    "course_nature_04": {
        "title": "石田河海",
        "description": "石、田、土、河、海、湖、泉。",
        "ids": ["hanzi_stone", "hanzi_field", "hanzi_soil", "hanzi_river", "hanzi_sea", "hanzi_lake", "hanzi_spring"],
    },
}


def load(name):
    with (ROOT / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def dump(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    existing = load("hanzi.json")
    seen = {item["id"] for item in existing}
    hanzi_list = list(existing)
    for item in NEW:
        if item["id"] not in seen:
            hanzi_list.append(item)
            seen.add(item["id"])

    characters = [item["character"] for item in hanzi_list]
    if len(characters) != len(set(characters)):
        raise SystemExit("字形重复")
    if not 80 <= len(hanzi_list) <= 100:
        raise SystemExit(f"字数 {len(hanzi_list)} 不在 80～100")

    by_id = {item["id"] for item in hanzi_list}
    courses = load("courses.json")
    links = []
    for course in courses:
        plan = COURSE_PLAN.get(course["id"])
        if plan is None:
            raise SystemExit(f"缺少课程计划 {course['id']}")
        missing = [item for item in plan["ids"] if item not in by_id]
        if missing:
            raise SystemExit(f"{course['id']} 缺字 {missing}")
        course["hanziIds"] = plan["ids"]
        course["description"] = plan["description"]
        course["exerciseTypes"] = EXERCISES
        if "title" in plan:
            course["title"] = plan["title"]
        for index, hanzi_id in enumerate(plan["ids"], start=1):
            links.append({
                "courseId": course["id"],
                "hanziId": hanzi_id,
                "sortOrder": index,
                "isReview": False,
            })

    manifest = load("manifest.json")
    manifest["plannedCourseCount"] = len(courses)
    manifest["plannedHanziCount"] = len(hanzi_list)
    manifest["sampleHanziCount"] = len(hanzi_list)

    dump("hanzi.json", hanzi_list)
    dump("courses.json", courses)
    dump("course_hanzi.json", links)
    dump("manifest.json", manifest)
    print(f"wrote {len(hanzi_list)} hanzi, {len(courses)} courses")
    runpy.run_path(str(Path(__file__).with_name("make_demo_assets.py")), run_name="__main__")


if __name__ == "__main__":
    main()
