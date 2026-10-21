# 参与《归宁》

欢迎报告问题、改进无障碍操作、修复错误和提交非商业改作。

提交前请阅读 `NOTICE.txt`：代码使用 PolyForm Noncommercial 1.0.0，自有内容使用 CC BY-NC-SA 4.0。提交贡献表示你有权提交，并同意贡献按对应许可分发；第三方作品必须单独注明来源与许可。

问题反馈请提供：游戏版本、系统版本、设备/显卡、操作步骤、预期与实际结果。涉及存档时请先复制备份，公开贴出前检查其中的时间和个人备注。

开发使用 Godot 4.7.2、GDScript、Compatibility。规则集中在 `scripts/game_core.gd`，界面不得绕过规则直接授予记忆。存档使用 schema 1，损坏或较新版本的存档不得覆盖。

运行 `pwsh -File tools/run-tests.ps1 -GodotPath <Godot可执行文件>`；测试只写 `.test-output/`。变更玩法或存档时，说明受影响流程与回归结果。不要提交构建产物、签名密钥、玩家存档或本机绝对路径。
