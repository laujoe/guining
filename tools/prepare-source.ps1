param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$version = Get-GuiningVersion
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$destination = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $projectRoot "dist/Guining-Source-$version" }
$zip = $destination + '.zip'
if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $zip)) { throw 'Source output already exists; choose a new directory.' }
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$rootFiles = @('README.md','LICENSE','NOTICE.txt','THIRD-PARTY-NOTICES.md','CONTRIBUTING.md','.gitignore','.gitattributes','export_presets.cfg')
foreach ($name in $rootFiles) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $destination }
foreach ($folder in @('scripts','scenes','data','tests','tools','licenses','.github')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $folder) -Recurse -File -Force) {
        if ($file.Extension -notin '.gd','.gdshader','.uid','.tscn','.json','.ps1','.iss','.md','.yml','.yaml','.txt') {
            throw "Unexpected source file type in $folder"
        }
        $target = Join-Path $destination ([IO.Path]::GetRelativePath($projectRoot, $file.FullName))
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
}
Copy-GuiningAssets $projectRoot $destination
New-Item -ItemType Directory -Force -Path (Join-Path $destination 'docs') | Out-Null
foreach ($name in @('ASSETS.md','BUILDING.md','RELEASING.md','RELEASE-0.1.3.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "docs/$name") -Destination (Join-Path $destination 'docs')
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'public-AGENTS.md') -Destination (Join-Path $destination 'AGENTS.md')
$config = Get-GuiningCleanConfig (Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw)
[IO.File]::WriteAllText((Join-Path $destination 'project.godot'), $config, [Text.UTF8Encoding]::new($false))
$manifest = @()
foreach ($file in Get-ChildItem -LiteralPath $destination -File -Recurse -Force) {
    $relative = [IO.Path]::GetRelativePath($destination, $file.FullName).Replace('\','/')
    if ($file.Length -ge 100MB) { throw "File exceeds GitHub's regular Git file limit: $relative" }
    if ($file.Extension -in '.gd','.gdshader','.tscn','.ps1','.iss','.md','.txt','.cfg','.godot','.json','.yml','.yaml' -or $file.Name -eq 'LICENSE') {
        $text = [IO.File]::ReadAllText($file.FullName)
        if ($text -match '(?i)[A-Z]:[/\\]Users[/\\][^/\\\s]+|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bsk-[A-Za-z0-9]{32,}') {
            throw "Potential local identity or credential in $relative"
        }
    }
    $manifest += [ordered]@{path=$relative;bytes=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$manifest | Sort-Object path | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $destination 'SOURCE-MANIFEST.json') -Encoding utf8
Compress-Archive -LiteralPath $destination -DestinationPath $zip -CompressionLevel Optimal
Get-Item -LiteralPath $destination,$zip | Select-Object FullName,Length
