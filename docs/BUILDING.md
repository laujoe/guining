# 构建与测试

## 环境

- Godot 4.7.2 Standard 与同版本导出模板。
- PowerShell 7（`pwsh`）。
- Android：OpenJDK 17、Android SDK，在 Godot 编辑器设置中配置 Java SDK Path 与 Android SDK Path。
- Windows 安装器：Inno Setup 6.7 或兼容版本。

将 `GODOT_PATH` 设为 Godot 可执行文件路径，或向脚本传入 `-GodotPath`。

## 测试

```powershell
pwsh -File tools/run-tests.ps1
```

测试覆盖游戏规则、界面、影路几何、存档、记忆图谱与多指输入，结果写入 `.test-output/`。

在桌面显示触屏控件：

```powershell
& $env:GODOT_PATH --path . -- --touch-controls
```

## Windows

```powershell
pwsh -File tools/package-windows.ps1 -PackageName Guining-Windows-0.1.3
pwsh -File tools/package-installer.ps1 `
  -PackageDirectory dist/Guining-Windows-0.1.3 `
  -IsccPath 'C:\Tools\Inno Setup 6\ISCC.exe'
```

构建脚本在 `.release/` 创建暂存工程，导出后检查包内资源并生成 ZIP。安装器从 ZIP 对应的目录打包，默认安装到 `%LOCALAPPDATA%\Programs\Guining`，卸载时保留 `%APPDATA%\Guining` 存档。

`tools/test-installer.ps1` 在 `.test-output/` 下验证安装与卸载。运行期间会创建当前用户的卸载注册项，结束后清除；检测到已有安装时停止。

## Android

```powershell
pwsh -File tools/package-android.ps1
```

输出 `dist/Guining-Android-0.1.3-test.apk`，包含 ARM64 与 x86_64，使用 Godot 配置的调试签名。发行签名在本地或 CI Secrets 中配置，签名文件与密码不提交到仓库。

安装到已连接设备：

```powershell
adb install -r dist/Guining-Android-0.1.3-test.apk
```

覆盖安装需要相同签名。更换签名前请备份存档。平台配置详见 [Godot Android 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。

## 源码快照

```powershell
pwsh -File tools/prepare-source.ps1
```

输出 `dist/Guining-Source-0.1.3/` 与 ZIP，包含代码、测试、成品素材和许可。`SOURCE-MANIFEST.json` 记录文件路径、大小与 SHA-256。

同名输出已存在时，使用 `-OutputDirectory` 指定新目录。发布流程见 [版本发布](RELEASING.md)。
