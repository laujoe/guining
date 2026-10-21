$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$version = Get-GuiningVersion
$dist = Join-Path $PSScriptRoot '../dist'
$names = @("Guining-Windows-$version.zip","Guining-Windows-$version-Setup.exe","Guining-Android-$version-test.apk")
$lines = foreach ($name in $names) {
    $hash = Get-FileHash -LiteralPath (Join-Path $dist $name) -Algorithm SHA256
    $hash.Hash.ToLowerInvariant() + '  ' + $name
}
$lines | Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Encoding utf8
$lines
