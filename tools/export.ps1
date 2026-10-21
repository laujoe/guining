param(
    [string]$GodotPath = '',
    [string]$OutputDirectory = '',
    [ValidateSet('Windows','Android')][string]$Platform = 'Windows'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$GodotPath = Resolve-GuiningGodot $GodotPath
$version = Get-GuiningVersion
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$releaseRoot = Join-Path $projectRoot ('.release/build-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
foreach ($folder in @('scenes','scripts')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $folder) -Destination $releaseRoot -Recurse
}
Copy-GuiningAssets $projectRoot $releaseRoot
New-Item -ItemType Directory -Force -Path (Join-Path $releaseRoot 'data') | Out-Null
foreach ($dataFile in @('game_config.json','dialogue_main.json','narrative.json','shadow_graph.json','manuscript_board.json','runner_timeline.json','memory_checkpoints.json')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('data/' + $dataFile)) -Destination (Join-Path $releaseRoot 'data')
}
$sourceConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
$clean = Get-GuiningCleanConfig $sourceConfig
[IO.File]::WriteAllText((Join-Path $releaseRoot 'project.godot'), $clean, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Destination $releaseRoot
$outputDir = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $projectRoot ('builds/' + $Platform.ToLowerInvariant()) }
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$artifactName = if ($Platform -eq 'Windows') { 'Guining.exe' } else { 'Guining-Android-test.apk' }
$artifactPath = Join-Path $outputDir $artifactName
if (Test-Path -LiteralPath $artifactPath) { throw "Output already exists; use a new OutputDirectory: $artifactPath" }
# Android is explicitly a debug-signed playtest, not a store/release-signed build.
$exportMode = if ($Platform -eq 'Android') { '--export-debug' } else { '--export-release' }
$savedCache = $env:LOCALAPPDATA
try {
    # Editor caches stay writable and isolated, while APPDATA retains SDK/template settings.
    $env:LOCALAPPDATA = Join-Path $releaseRoot '.editor-cache'
    New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
foreach ($operation in @('import','export')) {
    $arguments = if ($operation -eq 'import') { '--headless --editor --path "' + $releaseRoot + '" --import --quit' } else { '--headless --path "' + $releaseRoot + '" ' + $exportMode + ' ' + $Platform + ' "' + $artifactPath + '"' }
    $log = Join-Path $outputDir ($operation + '.log')
    $errors = Join-Path $outputDir ($operation + '-errors.log')
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
    if (-not $process.WaitForExit(240000)) { Stop-Process -Id $process.Id; throw ($operation + ' timed out') }
    $process.Refresh()
    $text = (Get-Content -LiteralPath $log -Raw) + (Get-Content -LiteralPath $errors -Raw)
    if ($process.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR|Parse Error|Compile Error|Export failed|Exporting failed|Project export.*failed') { throw ($operation + ' failed; inspect ' + $errors) }
}
} finally { $env:LOCALAPPDATA = $savedCache }
$artifact = Get-Item -LiteralPath $artifactPath -ErrorAction Stop
if ($artifact.Length -lt 1000000) { throw 'Exported executable is unexpectedly small.' }
$manifest = [ordered]@{version=$version;engine='4.7.2';platform=$Platform;mode=$exportMode;file=$artifact.Name;bytes=$artifact.Length;sha256=(Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash;excluded=@('addons','tests','tools','docs','.test-output','legacy-font')}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDir 'build-manifest.json') -Encoding utf8
$artifact | Select-Object FullName,Length
