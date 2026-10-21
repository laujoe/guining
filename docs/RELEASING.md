# 上传 GitHub 与分享试玩

推荐独立仓库 `guining`。仓库简介可用：

> 归宁：水墨叙事与小游戏。Godot 4.7.2，非商业源码公开，禁止未经授权的商业使用。

## 源码

先运行 `tools/prepare-source.ps1`，只把生成的 `dist/Guining-Source-<版本>/` **里面的文件**作为仓库根目录上传。不要上传整个游戏工作区，也不要上传本地开发目录的历史附件、其他游戏或工具缓存。

README、LICENSE、NOTICE、project.godot 应在仓库根目录。GitHub 可能将 PolyForm 标记为非标准/Other 许可，这是正常的；不要为了徽章改选 MIT，也不要添加允许商业使用的模板。

可通过 GitHub Desktop 添加该目录并发布 Public 仓库，或在该目录运行：

```powershell
git init
git add .
git diff --cached --stat
git commit -m "Publish Guining 0.1.3 for noncommercial use"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/guining.git
git push -u origin main
```

把示例账号替换为自己的账号。本次整理不自动创建仓库、不推送、不发布 Release。

## 试玩包

新建 `v0.1.3` Release，勾选预发行（Pre-release），上传：

- `Guining-Windows-0.1.3-Setup.exe`
- `Guining-Windows-0.1.3.zip`
- `Guining-Android-0.1.3-test.apk`
- `SHA256SUMS.txt`

这些文件作为 **Release 附件**，不提交进源码仓库。GitHub 自动生成的 Source code ZIP 仅用于开发，不是游戏安装包。

Release 说明写清：非商业使用；Windows 未做代码签名；Android 为调试签名测试 APK；哪些平台实际玩过、哪些仅构建检查。已构建、已实测和已上架是三个不同状态。

## 版本与验证

版本信息在 `project.godot` 和 `export_presets.cfg`，更新时同时增加 Android `version/code`。Windows ZIP 名称应与版本一致。

1. 运行完整自动测试。
2. 构建 Windows ZIP 并完成包内资源回归。
3. 从经过审核的 ZIP 目录制作 Setup。
4. 构建 APK，并用 Android SDK 的 `apksigner verify --verbose` 与 `aapt dump badging` 检查签名、包名和架构。
5. 在目标电脑和手机上做完整流程测试，单独记录未完成项目。
6. 用 `tools/write-checksums.ps1` 为现有三个试玩文件生成校验清单。
7. 确认源码快照无本机路径、密钥、存档与开发插件后上传。

原始设计与历史修复日志保留在开发者本机。公开的结构、许可、素材说明和构建说明已整理在 `docs/`。
