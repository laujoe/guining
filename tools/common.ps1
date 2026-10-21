$ErrorActionPreference = 'Stop'
function Resolve-GuiningGodot([string]$Requested) {
    if ($Requested) {
        if (Test-Path -LiteralPath $Requested -PathType Leaf) { return (Resolve-Path -LiteralPath $Requested).Path }
        $command = Get-Command $Requested -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
        throw "Godot executable not found: $Requested"
    }
    if ($env:GODOT_PATH) { return Resolve-GuiningGodot $env:GODOT_PATH }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $localEngine = Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { return (Resolve-Path -LiteralPath $localEngine).Path }
    throw 'Install Godot 4.7.2 and set GODOT_PATH or pass -GodotPath.'
}
function Get-GuiningVersion {
    $config = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../project.godot') -Raw
    if ($config -notmatch 'config/version="([0-9]+\.[0-9]+\.[0-9]+)"') { throw 'Missing project version.' }
    return $Matches[1]
}
function Get-GuiningCleanConfig([string]$SourceConfig) {
    foreach ($section in @('autoload','editor_plugins','debug')) {
        $SourceConfig = [regex]::Replace($SourceConfig, "(?ms)^\[$section\]\s*.*?(?=^\[|\z)", '')
    }
    return $SourceConfig
}
function Copy-GuiningAssets([string]$SourceRoot, [string]$DestinationRoot) {
    # Never ship import caches or the legacy font with unclear redistribution terms.
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'assets') -File -Recurse) {
        if ($file.Extension -eq '.import' -or $file.Name -eq 'YunFengJingLongXingShu.ttf') { continue }
        $relative = [IO.Path]::GetRelativePath($SourceRoot, $file.FullName)
        $destination = Join-Path $DestinationRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    $legal = Join-Path $DestinationRoot 'assets/legal'
    New-Item -ItemType Directory -Force -Path $legal | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'LICENSE') -Destination (Join-Path $legal 'CODE-LICENSE.txt')
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'NOTICE.txt'),(Join-Path $SourceRoot 'licenses/CC-BY-NC-SA-4.0.txt') -Destination $legal
}
