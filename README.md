# 归宁 · Guining

**纸上留人，灯下留席。**

《归宁》（又名《一叶生》）是一款由浙江大学学生团队主导创作的水墨叙事游戏，改编自《聊斋志异》中的叶生故事。跟随叶生，重访故友、学生与妻子的三段记忆，在提灯寻路、转镜接影与整理旧稿之间，拾回归途的线索。

![归宁场景图集](assets/backgrounds.png)

## 下载

在 [Releases](https://github.com/laujoe/guining/releases/latest) 下载游戏。游戏离线运行，无需注册账户或安装 Godot。

| 平台 | 下载 | 使用方式 |
| --- | --- | --- |
| Windows | [安装版](https://github.com/laujoe/guining/releases/download/v0.1.3/Guining-Windows-0.1.3-Setup.exe) | 双击安装后启动 |
| Windows | [便携版](https://github.com/laujoe/guining/releases/download/v0.1.3/Guining-Windows-0.1.3.zip) | 完整解压后运行 `Guining.exe` |
| Android | [APK](https://github.com/laujoe/guining/releases/download/v0.1.3/Guining-Android-0.1.3-test.apk) | 安装后横屏游玩 |

系统要求：Windows 10/11 x64、支持 OpenGL 3.3 的显卡；Android 7.0 及以上、支持 OpenGL ES 3.0 的 64 位设备。下载文件的校验值见 Release 中的 `SHA256SUMS.txt`。

## 游戏内容

- **三段记忆**：自由选择回忆顺序，重访叶生生命中的故人。
- **借光与转镜**：提灯探索丁府廊道，在悬浮书楼中调整视角、接通墨影。
- **理稿与批阵**：整理散落的书稿，挥笔应对纸兵与纸龙。
- **四季追信与拼玉**：穿行四季，收集记忆碎片，拼合玉佩。
- **记忆图谱**：回看已保存的节点，也可在暂停菜单中“记下此刻”。

提供文字大小、音量、减少动态、宽松笔锋和单击代替长按等设置。

## 操作

| 场景 | 键鼠 | 触屏 |
| --- | --- | --- |
| 对话 | 点击继续 / E / 空格 | 点击“继续” |
| 借光 | WASD / 方向键；拖动转头；M 地图 | 前进、后退、左右转向按钮；地图按钮 |
| 转镜 | Q/E 转视角；点击“入影”；拖动移灯 | 屏幕按钮与滑杆 |
| 理稿 | 点击最上层牌，同类三张消除 | 点击牌；使用撤销、暂存、取回按钮 |
| 批阵 | WASD / 方向键；J 挥笔；空格闪避 | 方向、挥笔和闪避按钮，支持组合操作 |
| 追信 | 空格跳；S 低身；按住 E 顶风 | 跳、低身、顶风按钮，支持组合操作 |
| 拼玉 | 拖动；Tab 选片、方向键、E 放置 | 拖动碎片；30 秒后可用辅助吸附 |
| 暂停 | Esc | 暂停按钮 / Android 返回键 |

对话第一次点击显示全文，再次点击推进。Windows 安装版与便携版共用 `%APPDATA%\Guining` 存档，卸载时保留进度；Android 存档位于应用目录。开始新故事会归档原有进度。

## 开发

使用 **Godot 4.7.2 Standard**，GDScript 与 Compatibility 渲染。导入 `project.godot`，按 F5 运行；入口为 `scenes/main.tscn`。

| 目录 | 内容 |
| --- | --- |
| `scripts/` | 游戏规则、界面与演出；核心规则位于 `game_core.gd` |
| `scenes/` | 游戏入口与记忆图谱界面 |
| `data/` | 对白、叙事和小游戏配置 |
| `assets/` | 美术、字体、音乐与许可 |
| `tests/` | 自动测试 |
| `tools/` | 测试、导出与打包脚本 |

构建和测试见 [构建指南](docs/BUILDING.md)，版本更新见 [0.1.3 更新记录](docs/RELEASE-0.1.3.md)。

## 许可

本项目以非商业许可公开源码，允许在许可范围内学习、修改和分享，**禁止未经授权的商业使用**。

| 范围 | 许可 |
| --- | --- |
| 自有代码与工程配置 | [PolyForm Noncommercial 1.0.0](LICENSE) |
| 自有剧情、数据、美术、音效和文档 | [CC BY-NC-SA 4.0](licenses/CC-BY-NC-SA-4.0.txt) |
| 第三方字体、音乐与引擎 | 各自原许可，见 [第三方说明](THIRD-PARTY-NOTICES.md) |

美术包含 AI 辅助生成作品与作者提供的原图。署名和素材来源见 [NOTICE](NOTICE.txt) 与 [素材说明](docs/ASSETS.md)。

## 反馈与贡献

欢迎通过 [Issues](https://github.com/laujoe/guining/issues) 反馈问题，请附上版本、设备与复现步骤。参与开发请阅读 [贡献指南](CONTRIBUTING.md)。
