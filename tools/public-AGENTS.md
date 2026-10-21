# 《归宁》贡献约定

- 独立 Godot 4.7.2 / GDScript / Compatibility 工程，入口 `scenes/main.tscn`。
- 代码为 PolyForm Noncommercial 1.0.0；自有内容为 CC BY-NC-SA 4.0。保留第三方原许可。不得改成允许商用的许可。
- 规则写入 `scripts/game_core.gd`，显示层不得绕过规则授予记忆。
- 三段记忆任意顺序、唯一结局；刻字仅翻玉后出现；人物簿通关后开放。
- 存档 schema 1；坏存档和较新 schema 不覆盖。新故事须确认并归档旧存档。
- 运行 `tools/run-tests.ps1`。测试只写 `.test-output/`；禁止读写玩家存档。
- 发包使用 `tools/export.ps1` 的干净暂存工程；不要包含插件、测试、凭据和本机路径。
- 原始附件与内部文档不在公开仓库内。维护公开文档即可，无需寻找其他游戏工程。
- 不把构建成功描述为实机验证或商店上线。
