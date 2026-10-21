param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$version = Get-GuiningVersion
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runRoot = Join-Path $projectRoot ('.test-output/android-' + [guid]::NewGuid().ToString('N'))
$dist = Join-Path $projectRoot 'dist'
$target = Join-Path $dist "Guining-Android-$version-test.apk"
if (Test-Path -LiteralPath $target) { throw 'APK exists; preserve it and use a new version.' }
& (Join-Path $PSScriptRoot 'export.ps1') -GodotPath $GodotPath -Platform Android -OutputDirectory $runRoot
$apk = Join-Path $runRoot 'Guining-Android-test.apk'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($apk)
try {
    $entries = @($archive.Entries | ForEach-Object FullName)
    foreach ($required in @('AndroidManifest.xml','lib/arm64-v8a/libgodot_android.so','lib/x86_64/libgodot_android.so','assets/assets/legal/NOTICE.txt','assets/assets/legal/CODE-LICENSE.txt')) {
        if ($entries -notcontains $required) { throw "APK missing $required" }
    }
    if ($entries -match '^assets/(addons|tests|tools|docs)/|YunFeng|\.keystore$|\.jks$') { throw 'APK contains excluded resources.' }
} finally { $archive.Dispose() }
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item -LiteralPath $apk -Destination $target
Get-FileHash -LiteralPath $target -Algorithm SHA256
