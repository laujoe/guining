# 构建与测试

## 环境

- Godot 4.7.2 Standard 与同版本官方导出模板；Compatibility 渲染。
- Windows 构建脚本使用 PowerShell 7（`pwsh`）。
- 将 `GODOT_PATH` 设为引擎可执行文件，或在命令中传 `-GodotPath`。不要把本机路径提交到导出配置。
- Android：OpenJDK 17、Android SDK；在 Godot 编辑器设置中填入 Java SDK Path 与 Android SDK Path。参见 [官方 Android 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。
- Windows 安装器：Inno Setup 6.7 或兼容版本的 `ISCC.exe`。

## 验证

```powershell
pwsh -File tools/run-tests.ps1 -GodotPath 'C:\Tools\Godot\godot.exe'
```

所有测试结果与隔离存档写入 `.test-output/`。测试覆盖规则、UI、影路几何、存档、记忆图谱、版本回归及双指触屏输入。图形渲染、GPU 性能和真机触控仍需要人工验收。

桌面模拟触屏布局：

```powershell
& $env:GODOT_PATH --path . -- --touch-controls
```

该参数只显示移动端按钮；多指输入测试由 `tests/test_mobile.gd` 注入 ScreenTouch 事件。

## Windows ZIP 与安装包

```powershell
pwsh -File tools/package-windows.ps1 -PackageName Guining-Windows-0.1.3
pwsh -File tools/package-installer.ps1 `
  -PackageDirectory dist/Guining-Windows-0.1.3 `
  -IsccPath 'C:\Tools\Inno Setup 6\ISCC.exe'
```

ZIP 脚本从全新的 `.release/build-*/` 白名单工程构建，检查 EXE 内嵌文件并对包内资源执行 `test_revision.gd`，扫描本机身份标识，解压核对哈希，再独立启动程序。安装器只接受与成功审核哈希一致的文件目录。

安装器默认安装到当前用户的 `%LOCALAPPDATA%\Programs\Guining`，无需管理员权限；可选桌面快捷方式。卸载器只卸载应用文件，保留 `%APPDATA%\Guining` 的玩家存档。

`tools/test-installer.ps1` 可在新的 `.test-output/installer-*/` 目录验证安装、哈希、启动和卸载。它会暂时写入当前用户的卸载注册项，完成后由卸载器清除；发现已安装的归宁时立即停止，不替换现有安装。

## Android 测试 APK

```powershell
pwsh -File tools/package-android.ps1
```

输出 `dist/Guining-Android-0.1.3-test.apk`，包含 ARM64 和 x86_64；横屏，关闭联网权限。使用 Godot 配置的调试签名，可供侧载试玩；不将此包描述为 release 签名或商店上架包。

未来正式发布需在本地或 CI Secrets 中配置发行签名，稳定保管同一私钥，并提高 `version/code`。不得把 `.keystore`、密码、`export_credentials.cfg` 提交到 Git；不要把调试签名当作长期升级签名。

真机建议依次验证：冷启动与中文字体、完整三段记忆、双指批阵、迷宫行走与地图、顶风跳跃、拖动拼玉、暂停/切后台/恢复、存档和完整终章。用 `adb install -r <apk>` 安装；签名冲突时先备份，不能直接卸载玩家现有数据。

## 干净源码快照

```powershell
pwsh -File tools/prepare-source.ps1
```

该命令创建新的 `dist/Guining-Source-0.1.3/` 与 ZIP，使用明确白名单，不携带 `.git` 历史、开发插件、原始附件、旧构建、玩家存档和签名文件。保留源代码、测试、成品素材与完整许可，并移除开发插件配置。`SOURCE-MANIFEST.json` 记录每个文件的相对路径、大小和 SHA-256；准备上传前应在该目录重新跑测试。

已经存在同名产物时脚本会停止。保留已分享的包并提升版本或使用新输出目录，不覆盖别人的下载目标。
