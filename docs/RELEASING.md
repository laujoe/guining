# 版本发布

## 更新版本

同步修改 `project.godot` 和 `export_presets.cfg` 中的版本号，并递增 Android 的 `version/code`。在 `docs/` 更新对应版本的变更记录。

## 构建

按 [构建指南](BUILDING.md) 运行测试并生成 Windows 安装版、便携版与 Android APK。使用 `tools/write-checksums.ps1` 生成 `SHA256SUMS.txt`。

开发工作区通过 `tools/prepare-source.ps1` 生成公开源码快照。将快照内容作为仓库根目录，检查提交差异后推送。

## 发布 Release

1. 为发布提交创建 `v<版本号>` 标签。
2. 创建对应 Release，填写游戏更新内容与下载入口。
3. 上传 Windows Setup、Windows ZIP、Android APK 和 `SHA256SUMS.txt`。
4. 核对附件名称、下载链接与校验值。

构建产物存放在 Release 附件中。GitHub 自动生成的 Source code 压缩包用于源码开发。
