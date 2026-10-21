param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
# Runtime music transitions also have a windowed/Dummy-driver check: tests/test_music.gd.
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$engine = Resolve-GuiningGodot $GodotPath
$testRoot = Join-Path $projectRoot '.test-output'
New-Item -ItemType Directory -Force -Path (Join-Path $testRoot 'local'),(Join-Path $testRoot 'roaming') | Out-Null
$originalLocalAppData = $env:LOCALAPPDATA
$originalAppData = $env:APPDATA
try {
    $env:LOCALAPPDATA = Join-Path $testRoot 'local'
    $env:APPDATA = Join-Path $testRoot 'roaming'
    $importLog = & $engine --headless --path $projectRoot --editor --import --quit 2>&1 | Out-String
    $importLog | Set-Content -LiteralPath (Join-Path $testRoot 'test-import.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0 -or $importLog -match 'SCRIPT ERROR|Parse Error|Compile Error') { throw $importLog }
    foreach ($test in @(@('run_tests.gd','rules-results.json'),@('test_ui.gd','ui-results.json'),@('test_shadow_3d.gd','shadow-results.json'),@('test_memory_saves.gd','memory-results.json'),@('test_memory_ui.gd','memory-ui-results.json'),@('test_revision.gd','revision-results.json'),@('test_mobile.gd','mobile-results.json'))) {
        $log = & $engine --headless --path $projectRoot --script ('res://tests/' + $test[0]) 2>&1 | Out-String
        $log | Set-Content -LiteralPath (Join-Path $testRoot ($test[0] + '.log')) -Encoding utf8
        if ($LASTEXITCODE -ne 0 -or $log -match 'SCRIPT ERROR|FAIL UI:|FAIL:') { throw $log }
        $report = Get-Content -LiteralPath (Join-Path $testRoot $test[1]) -Raw | ConvertFrom-Json
        if ($report.failures.Count -gt 0) { throw ($report.failures -join "`n") }
        Write-Output ($test[0] + ': ' + $report.checks + ' checks passed')
    }
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:APPDATA = $originalAppData
}
