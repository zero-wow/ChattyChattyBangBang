[CmdletBinding()]
param([switch] $List)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$tests = @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'Tests') -File -Filter '*.mock.lua' | Sort-Object Name)
if ($tests.Count -eq 0) { throw 'No local Lua mock tests were found.' }
if ($List) {
    $tests | ForEach-Object { Write-Host $_.Name }
    Write-Host 'DeployPackage.mock.ps1'
    Write-Host "$($tests.Count) Lua mocks and 1 temp-stage package test inventoried."
    return
}

$lua = Get-Command -Name lua -ErrorAction SilentlyContinue
if (-not $lua) { throw 'lua is required to run the local mock suite.' }
$failures = @()
Push-Location $sourceRoot
try {
    foreach ($test in $tests) {
        $relative = "Tests/$($test.Name)"
        Write-Host "RUN $relative"
        & $lua.Source $relative
        if ($LASTEXITCODE -ne 0) { $failures += $relative }
    }
}
finally { Pop-Location }

if ($failures.Count -gt 0) {
    throw "$($failures.Count) of $($tests.Count) Lua mock tests failed: $($failures -join ', ')"
}
& (Join-Path $sourceRoot 'Tests\DeployPackage.mock.ps1')
Write-Host "PASS: $($tests.Count) Lua mocks and 1 temp-stage package test. No WoW client behavior was exercised."
