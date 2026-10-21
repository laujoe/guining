param([string]$InstallerPath = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$version = Get-GuiningVersion
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $InstallerPath) { $InstallerPath = Join-Path $projectRoot "dist/Guining-Windows-$version-Setup.exe" }
$InstallerPath = (Resolve-Path -LiteralPath $InstallerPath).Path
$registration = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{6714E158-757F-4DF0-8D03-35DD27A7489E}_is1'
if (Test-Path -LiteralPath $registration) { throw 'Guining is already installed; do not replace a player installation for testing.' }
$testRoot = Join-Path $projectRoot ('.test-output/installer-' + [guid]::NewGuid().ToString('N'))
$installRoot = [IO.Path]::GetFullPath((Join-Path $testRoot 'application'))
if (-not $installRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Installer test must stay in the project.' }
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$savedRoaming = $env:APPDATA
$savedLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $testRoot 'roaming'
    $env:LOCALAPPDATA = Join-Path $testRoot 'local'
    $saveMarker = Join-Path $env:APPDATA 'Guining/preserve-test.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $saveMarker),$env:LOCALAPPDATA | Out-Null
    'Preserve player data on uninstall.' | Set-Content -LiteralPath $saveMarker
    $arguments = '/CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /TASKS="" /DIR="' + $installRoot + '" /LOG="' + (Join-Path $testRoot 'install.log') + '"'
    $setup = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $setup.WaitForExit(60000)) { throw 'Installer did not finish within 60 seconds.' }
    $setup.Refresh()
    if ($setup.ExitCode -ne 0) { throw "Installer exited with $($setup.ExitCode); inspect $testRoot" }
    $expected = Join-Path $projectRoot "dist/Guining-Windows-$version/Guining.exe"
    $installed = Join-Path $installRoot 'Guining.exe'
    if ((Get-FileHash -LiteralPath $expected).Hash -ne (Get-FileHash -LiteralPath $installed).Hash) { throw 'Installed EXE hash mismatch.' }
    foreach ($file in @('LICENSE','NOTICE.txt','ENGINE-LICENSES.txt','licenses/CC-BY-NC-SA-4.0.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $installRoot $file))) { throw "Installed package is missing $file" }
    }
    $smokeLog = Join-Path $testRoot 'smoke.log'
    $game = Start-Process -FilePath $installed -WorkingDirectory $installRoot -ArgumentList ('--headless --quit-after 120 --log-file "' + $smokeLog + '"') -WindowStyle Hidden -PassThru
    if (-not $game.WaitForExit(30000)) { Stop-Process -Id $game.Id; throw 'Installed game did not finish smoke test.' }
    $game.Refresh()
    if ($game.ExitCode -ne 0 -or (Get-Content -LiteralPath $smokeLog -Raw) -match 'SCRIPT ERROR|Failed loading|Parse Error') { throw 'Installed game failed smoke test.' }
    # Verify the absolute uninstall target before invoking its recursive file cleanup.
    $uninstaller = (Resolve-Path -LiteralPath (Join-Path $installRoot 'unins000.exe')).Path
    if (-not $uninstaller.StartsWith($installRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected uninstaller location.' }
    $uninstall = Start-Process -FilePath $uninstaller -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="' + (Join-Path $testRoot 'uninstall.log') + '"') -WindowStyle Hidden -PassThru
    if (-not $uninstall.WaitForExit(60000)) { throw 'Uninstaller did not finish within 60 seconds.' }
    $uninstall.Refresh()
    if ($uninstall.ExitCode -ne 0 -or (Test-Path -LiteralPath $installed) -or (Test-Path -LiteralPath $registration)) { throw 'Uninstall did not complete.' }
    if (-not (Test-Path -LiteralPath $saveMarker)) { throw 'Uninstall removed the save marker.' }
    [ordered]@{install='passed';installed_executable_hash='passed';launch='passed';uninstall='passed';save_preserved='passed'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot '.test-output/installer-audit.json') -Encoding utf8
    Write-Output 'Installer: install, hash, launch, uninstall and save preservation passed.'
} finally {
    $env:APPDATA = $savedRoaming
    $env:LOCALAPPDATA = $savedLocal
}
