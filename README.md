# 识字森林

学习森林（LearnForest）家族里的中文识字 iPad App。商店和启动名是 **识字森林**。工程模块名是 **LearnForest**，Bundle ID 是 `com.learnforest.shizi`。

这不是英语森林 / Word Forest。英语线以后可以复用设计系统和本地档案，但用自己的内容包，不在这个目标里实现。

当前进度是 **Sprint 1：基础可跑**。可以离线浏览已装课程，从首页进入占位预习，并按档案记住进度。练习引擎、真实录音、插画、账号和内购都还没做。开发节奏见仓库根目录的 `开发计划.md`。

## 环境

- Mac 上的 Xcode 16.3 或更新版本（依赖 [GRDB 7](https://github.com/groue/GRDB.swift)，需要 Swift 6.1 工具链）
- 最低系统 **iPadOS 17.0**，目标设备只有 iPad
- 横屏优先，竖屏也能用

这套骨架是在没有 Xcode 的环境里提交的，没有跑过 `xcodebuild`。请在 Mac 上按下面步骤打开。

## 用 Xcode 打开

1. 克隆仓库，打开 `LearnForest.xcodeproj`。
2. 等 Swift Package 解析完成（GRDB）。如果没拉下来：File → Packages → Resolve Package Versions。
3. 选中目标 LearnForest，Signing 里选你的 Team。模拟器可以直接跑。
4. 运行目标选一台 **iPad** 模拟器（iPadOS 17 或更高）。
5. 关掉模拟器网络后再跑，确认不弹出联网提示。验收时看这些：
   - 首页超大「今日学习」，底栏是首页 / 认字 / 我的字卡
   - 点进去能看到本机课程里的字；点「下一个」后回到首页，按钮变成「继续学习」
   - 「我的字卡」里刚翻过的字是「学习中」，不是「初步掌握」
   - 右上角锁图标，成人乘法题通过后新建第二个档案并切换；第二个档案没有第一个的「学习中」
   - 删除要先点「我已了解，继续」，再点「删除档案」
   - 「认字」里三个主题都能打开，但没有「开始正式学习」。缺图、缺录音或练习未做的课不能进正式课

图标槽是空的，归档前需要放一张 1024×1024 的图。

## 本地优先

学习记录写在本机 SQLite（Application Support 里的 `learnforest.sqlite`）。没有网络也能打开已装进包里的课。V1.0 **不登录、不同步、不下载课程**。

表上留了 `syncStatus`、`schemaVersion`、`deviceId`、`deletedAt`。课程包清单里的 `remoteUpdate.enabled` 固定为 `false`。这些只是以后云同步和远程更新的位置，现在没有网络请求。

## 目录

```text
LearnForest.xcodeproj          Xcode 工程
LearnForest/
  App/                         SwiftUI 入口、根导航
  Features/Home                首页大按钮、家长入口
  Features/Learn               主题、课程、样例字
  Features/Cards               我的字卡
  Features/Parent              成人验证、档案和设置
  Domain/                      档案、课程、学习记录、上架门槛
  Data/                        GRDB 迁移、Repository
  DesignSystem/                色板、大按钮、卡片
  Resources/                   图标槽、隐私清单、课程包位置说明
Content/core_chinese_v1/       打进 App 的本地课程包
Content/templates/             Excel/CSV 模板和导出说明
```

页面不直接碰数据库。档案走 `ChildProfileStoring`，学习记录查询走 `LearningStoring`。

## 和 PRD V1.0 的对应

| PRD | 骨架里有什么 |
|---|---|
| §1 品牌 | 显示名「识字森林」，模块 LearnForest，英语线只留名字 |
| §3 底栏 + 首页主按钮 | 三个儿童 Tab；家长设置可改成「仅首页大卡片」 |
| §5.1 今日学习 / 继续学习 | 大按钮。没有进行中的课时显示「今日学习」 |
| §5.2 三个首发主题 | 动物世界、家庭生活、自然世界 |
| §5.9 家长验证 | 成人乘法题，答案不进 UserDefaults；进后台后要重验 |
| §5.10 今日一览 | 家长页短列表，不放图表 |
| §5.13 本地多档案 | `childProfile` 表，可新建、切换、改名、删除（两次确认） |
| §6 掌握状态 / 时长 / 奖励 | 占位预习只记「学习中」；不升掌握、不发奖、不到点结束 |
| §7 约 12 课、80～100 字 | 12 节课占位、16 个样例字；计划字数 90 |
| §7.4 上架门槛 | 没有真实图和录音的课不能进入 |
| §8 数据实体 | 档案、学习记录、会话、答题、奖励表 |
| §9 本地优先 | 课程包随 App；远程更新只留字段 |
| §16 SwiftUI + GRDB | 已按这个选型 |
| §17 绘本风 | 奶油底、大圆角、无常驻吉祥物 |

## 还没做

代码里标了 `TODO`：

- 练习引擎（听音找图、看字找图、配对）和学习结果
- AVFoundation 播放本地标准录音；禁止用在线语音合成当主路径
- 真实插画和音频文件
- 单次 / 每日时长到点后的温和结束
- 安静模式接到声音
- 账号、内购、云同步、远程课程下载

## 内容管线

编辑源是 Excel/CSV，运行时是 JSON。说明在 [`Content/templates/README.md`](Content/templates/README.md)。

## Sprint 2 建议先做

1. 在 Mac 上编过 iPad 模拟器，按上面的验收清单点一遍。
2. 把占位预习换成真正的学习准备页和汉字卡片，并接上本地发音。
3. 记住退出位置，做单次 / 每日时长到点后的温和结束。
4. 安静模式先接到声音开关，仍然先不要做题。
