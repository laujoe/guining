param(
    [string]$GodotPath = '',
    [ValidatePattern('^[A-Za-z0-9.-]+$')][string]$PackageName = ('Guining-Windows-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$GodotPath = Resolve-GuiningGodot $GodotPath
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runRoot = Join-Path $projectRoot ('.test-output/package-' + [guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
$inspection = Join-Path $runRoot 'inspection'
$emptyProject = Join-Path $runRoot 'empty'
$dist = Join-Path $projectRoot 'dist'
$package = Join-Path $dist $packageName
$zip = Join-Path $dist ($packageName + '.zip')
if ((Test-Path -LiteralPath $package) -or (Test-Path -LiteralPath $zip)) { throw 'Package already exists. Preserve or rename it before creating a replacement.' }
New-Item -ItemType Directory -Force -Path $runRoot,$emptyProject | Out-Null
& (Join-Path $PSScriptRoot 'export.ps1') -GodotPath $GodotPath -OutputDirectory $buildRoot | Out-Null
$savedLocal = $env:LOCALAPPDATA
$savedRoaming = $env:APPDATA
try {
    $env:LOCALAPPDATA = Join-Path $runRoot 'local'
    $env:APPDATA = Join-Path $runRoot 'roaming'
    New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA,$env:APPDATA | Out-Null
    $auditLogPath = Join-Path $runRoot 'pack-audit.log'
    $auditErrors = Join-Path $runRoot 'pack-audit-errors.log'
    $auditArgs = '--headless --path "' + $emptyProject + '" --script "' + (Join-Path $projectRoot 'tests/audit_pack.gd') + '" -- "' + (Join-Path $buildRoot 'Guining.exe') + '" "' + $inspection + '"'
    $auditProcess = Start-Process -FilePath (Resolve-Path -LiteralPath $GodotPath).Path -ArgumentList $auditArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $auditLogPath -RedirectStandardError $auditErrors
    if (-not $auditProcess.WaitForExit(60000)) { Stop-Process -Id $auditProcess.Id; throw 'Pack inspection timed out.' }
    $auditProcess.Refresh()
    $auditLog = (Get-Content -LiteralPath $auditLogPath -Raw) + (Get-Content -LiteralPath $auditErrors -Raw)
    if ($auditProcess.ExitCode -ne 0 -or $auditLog -notmatch 'PACK_AUDIT_EXTRACTED' -or $auditLog -match 'SCRIPT ERROR|Could not inspect|Could not load') { throw 'Pack inspection failed.' }
    $packedFiles = @(Get-Content -LiteralPath (Join-Path $inspection 'pack-files.json') -Raw | ConvertFrom-Json)
    # Execute the same regression suite against the actual embedded resources.
    $runtimeOutput = Join-Path $runRoot 'pack-runtime'
    New-Item -ItemType Directory -Force -Path $runtimeOutput | Out-Null
    $runtimeArgs = '--headless --path "' + $emptyProject + '" --script "' + (Join-Path $projectRoot 'tests/test_revision.gd') + '" -- "' + (Join-Path $buildRoot 'Guining.exe') + '" "' + $runtimeOutput + '"'
    $runtimeLog = Join-Path $runRoot 'pack-runtime.log'
    $runtimeErrors = Join-Path $runRoot 'pack-runtime-errors.log'
    $runtimeProcess = Start-Process -FilePath (Resolve-Path -LiteralPath $GodotPath).Path -ArgumentList $runtimeArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $runtimeLog -RedirectStandardError $runtimeErrors
    if (-not $runtimeProcess.WaitForExit(60000)) { Stop-Process -Id $runtimeProcess.Id; throw 'Pack runtime checks timed out.' }
    $runtimeProcess.Refresh()
    $runtimeText = (Get-Content -LiteralPath $runtimeLog -Raw) + (Get-Content -LiteralPath $runtimeErrors -Raw)
    if ($runtimeProcess.ExitCode -ne 0 -or $runtimeText -notmatch 'REVISION: .*0 failures' -or $runtimeText -match 'SCRIPT ERROR|FAIL REVISION:') { throw 'Pack runtime checks failed; inspect pack-runtime logs.' }
    foreach ($entry in $packedFiles) {
        if ($entry -notmatch '^res://(assets/|scenes/|scripts/|data/(game_config|dialogue_main|narrative|shadow_graph|manuscript_board|runner_timeline|memory_checkpoints)\.json$|project\.binary$|\.godot/(imported/|exported/|global_script_class_cache\.cfg$|uid_cache\.bin$))') {
            throw "Unexpected packed resource: $entry"
        }
    }
    # Search actual bytes, including compiled token buffers and UTF-16 strings.
    $needles = @($env:USERNAME,$env:COMPUTERNAME,$env:USERPROFILE) | Where-Object { $_ -and $_.Length -ge 3 } | Select-Object -Unique
    $latin = [Text.Encoding]::Latin1
    $patterns = foreach ($needle in $needles) {
        foreach ($encoding in @([Text.Encoding]::UTF8,[Text.Encoding]::Unicode,[Text.Encoding]::BigEndianUnicode)) {
            $latin.GetString($encoding.GetBytes($needle))
        }
    }
    $scanFiles = @((Get-Item -LiteralPath (Join-Path $buildRoot 'Guining.exe'))) + @(Get-ChildItem -LiteralPath $inspection -Recurse -File)
    foreach ($file in $scanFiles) {
        $raw = $latin.GetString([IO.File]::ReadAllBytes($file.FullName))
        foreach ($pattern in $patterns) {
            if ($raw.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) { throw ('Private identifier found in ' + $file.Name) }
        }
    }
    New-Item -ItemType Directory -Force -Path $package | Out-Null
    Copy-Item -LiteralPath (Join-Path $buildRoot 'Guining.exe') -Destination $package
    Copy-Item -LiteralPath (Join-Path $inspection 'ENGINE-LICENSES.txt') -Destination $package
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/FONT-NOTICE.txt'),(Join-Path $projectRoot 'assets/fonts/LXGWWenKai-OFL.txt') -Destination $package
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/music/MUSIC-NOTICE.txt'),(Join-Path $projectRoot 'assets/music/music-sources.json') -Destination $package
    Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE'),(Join-Path $projectRoot 'NOTICE.txt'),(Join-Path $projectRoot 'THIRD-PARTY-NOTICES.md') -Destination $package
    Copy-Item -LiteralPath (Join-Path $projectRoot 'licenses') -Destination $package -Recurse
    $readme = @'
归宁 · Windows 试玩版

解压整个文件夹，双击 Guining.exe 开始游玩。无需安装 Godot，无需联网。
适用于 Windows 10/11 64 位；需要支持 OpenGL 3.3 的显卡。中文字体已内置，无需安装。

鼠标点击按钮；E / 空格推进对话；Esc 暂停。小游戏内有各自的操作提示。
借光：W/S 前进后退，A/D 转向，或拖动画面转头；提灯探索丁府廊道。
按 M 打开鸟瞰图，可查看当前位置、朝向、出口，并选择显示路线。
转镜：Q/E 转视角，金线接合后点击“入影”；高台拖动滑杆移灯后再转视角接影。
首次按下继续键会立即显示整句，再按一次进入下一句。
设置可调整文字大小、音量、减少动态、宽松笔锋和单击辅助。
离开窗口后游戏自动暂停，回来时点击继续即可。

包含序章、三段可自由选择顺序的记忆、小游戏与终章。
理稿每局打乱牌面内容，保证有解；旧局读档保持原布局。第三段告别完成时立即记录玉佩进度。
内置按场景切换的背景音乐，以及落水、打捞离魂、灯下团圆的完整动态插画演出。
收齐玉佩、拼合翻面并读完刻字后进入终章；回答“来了”后播放团圆段。
主菜单的“记忆图谱”可读取、删除历史卷轴；关键节点自动收入图谱，暂停时“记下此刻”可手动保存一卷。
读取历史卷轴前会保留当前进度。动作小游戏从安全检查点继续，设定不会随读档回滚。
这是首个完整流程试玩版，美术与演出仍会继续完善。
游戏会在本机 %APPDATA%\Guining 创建独立存档；本包未附带任何玩家存档。

非商业试玩与分享；禁止未经授权的商业使用。具体范围见 NOTICE.txt 和 LICENSE。
本包仅含游戏程序、这份说明和项目／引擎／字体／音乐许可说明。
配乐署名与来源见 MUSIC-NOTICE.txt 和 music-sources.json，游戏主菜单也提供“配乐鸣谢”。
字体来源与许可见 FONT-NOTICE.txt 和 LXGWWenKai-OFL.txt。
Godot 引擎及第三方组件许可见 ENGINE-LICENSES.txt。
https://godotengine.org/license/
'@
    [IO.File]::WriteAllText((Join-Path $package '开始游玩.txt'), $readme, [Text.UTF8Encoding]::new($true))
    Compress-Archive -LiteralPath $package -DestinationPath $zip -CompressionLevel Optimal
    $unpacked = Join-Path $runRoot 'unpacked'
    Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
    $testExe = Join-Path $unpacked ($packageName + '/Guining.exe')
    $expectedHash = (Get-FileHash -LiteralPath (Join-Path $package 'Guining.exe') -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $testExe -Algorithm SHA256).Hash -ne $expectedHash) { throw 'ZIP round-trip checksum mismatch.' }
    $smokeLogPath = Join-Path $runRoot 'smoke.log'
    $process = Start-Process -FilePath $testExe -WorkingDirectory (Split-Path -Parent $testExe) -ArgumentList @('--headless','--quit-after','120','--log-file',('"' + $smokeLogPath + '"')) -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(30000)) { throw 'Packaged executable did not exit in 30 seconds.' }
    $process.Refresh()
    $exitCode = $process.ExitCode
    $smoke = Get-Content -LiteralPath $smokeLogPath -Raw
    if ($exitCode -ne 0 -or $smoke -match 'SCRIPT ERROR|Parse Error|Failed loading|Cannot open|Failed to load') { throw 'Packaged executable smoke test failed.' }
    $report = [ordered]@{
        package=$packageName; runtime_resources=$packedFiles.Count; packed_regression='passed'; identifier_scan='passed'; zip_roundtrip='passed'; smoke_exit=$exitCode
        included=@('Guining.exe','开始游玩.txt','ENGINE-LICENSES.txt','FONT-NOTICE.txt','LXGWWenKai-OFL.txt','MUSIC-NOTICE.txt','music-sources.json','LICENSE','NOTICE.txt','THIRD-PARTY-NOTICES.md','licenses/'); executable_sha256=$expectedHash
        zip_sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    }
    $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $projectRoot '.test-output/share-audit.json') -Encoding utf8
    Get-Item -LiteralPath $zip | Select-Object FullName,Length
    $report | ConvertTo-Json -Depth 4
} finally {
    $env:LOCALAPPDATA = $savedLocal
    $env:APPDATA = $savedRoaming
}
