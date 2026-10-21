param(
    [Parameter(Mandatory)][string]$PackageDirectory,
    [string]$IsccPath = 'ISCC.exe'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$version = Get-GuiningVersion
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dist = Join-Path $projectRoot 'dist'
$output = Join-Path $dist "Guining-Windows-$version-Setup.exe"
if (Test-Path -LiteralPath $output) { throw 'Installer exists; preserve it and use a new version.' }
# Avoid recursively packaging logs or accidental nested copies.
$allowed = @('Guining.exe','开始游玩.txt','ENGINE-LICENSES.txt','FONT-NOTICE.txt','LXGWWenKai-OFL.txt','MUSIC-NOTICE.txt','music-sources.json','LICENSE','NOTICE.txt','THIRD-PARTY-NOTICES.md','licenses/CC-BY-NC-SA-4.0.txt')
$actual = @(Get-ChildItem -LiteralPath $package -File -Recurse | ForEach-Object { [IO.Path]::GetRelativePath($package, $_.FullName).Replace('\','/') })
if (Compare-Object ($allowed | Sort-Object) ($actual | Sort-Object)) { throw 'Package file allowlist mismatch; run package-windows.ps1 first.' }
$audit = Get-Content -LiteralPath (Join-Path $projectRoot '.test-output/share-audit.json') -Raw | ConvertFrom-Json
if ($audit.packed_regression -ne 'passed' -or $audit.executable_sha256 -ne (Get-FileHash (Join-Path $package 'Guining.exe')).Hash) {
    throw 'Package has no matching successful embedded-resource audit.'
}
& $IsccPath "/DPackageDir=$package" "/DOutputDir=$dist" "/DAppVersion=$version" (Join-Path $PSScriptRoot 'installer.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
Get-FileHash -LiteralPath $output -Algorithm SHA256
