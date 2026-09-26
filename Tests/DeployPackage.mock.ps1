# No-client package smoke test. Creates and removes only a unique temp folder.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $tempParent ('ccbb-package-test-' + [guid]::NewGuid().ToString('N'))
$testFull = [System.IO.Path]::GetFullPath($testRoot)
if (-not $testFull.StartsWith($tempParent + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create package test outside temp: $testFull"
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    & (Join-Path $sourceRoot 'Tools\Deploy-ChattyChattyBangBang.ps1') -StageOnly -StageOutputRoot $testRoot
    $stage = Join-Path $testRoot 'ChattyChattyBangBang'
    if (-not (Test-Path -LiteralPath $stage -PathType Container)) { throw 'StageOnly did not preserve the requested temp package.' }
    if (Test-Path -LiteralPath (Join-Path $stage 'Modules')) { throw 'Dormant legacy Modules were included in Retail stage.' }

    $modulesXml = Get-Content -LiteralPath (Join-Path $stage 'modules.xml') -Raw
    if ($modulesXml -match '(?i)<\s*(Script|Include)\b') { throw 'Retail modules.xml still loads legacy modules.' }

    $manifest = Get-Content -LiteralPath (Join-Path $stage '.ccbb-deployment.json') -Raw | ConvertFrom-Json
    $head = (git -C $sourceRoot rev-parse HEAD).Trim()
    if ($manifest.sourceCommit -ne $head -or $manifest.client -ne 'Retail') { throw 'Stage provenance has the wrong source or client.' }
    if ($manifest.sourceTreeDirty -isnot [bool] -or $manifest.runtimeInputsDirty -isnot [bool] -or
        $manifest.packagingInputsDirty -isnot [bool]) {
        throw 'Stage provenance omitted dirty-tree flags.'
    }
    $treeDirty = @(git -C $sourceRoot status --porcelain --untracked-files=all).Count -gt 0
    $runtimeInputs = @('ChattyChattyBangBang.lua', 'ChattyChattyBangBang.toc', 'modules.xml',
        'Core', 'Libs', 'Localization', 'Media', 'Providers')
    $runtimeDirty = @(git -C $sourceRoot status --porcelain --untracked-files=all -- $runtimeInputs).Count -gt 0
    $packagingInputs = @('Tools/Deploy-ChattyChattyBangBang.ps1', 'Tools/Test-RetailPackage.ps1',
        'Packaging/targets.psd1')
    $packagingDirty = @(git -C $sourceRoot status --porcelain --untracked-files=all -- $packagingInputs).Count -gt 0
    if ($manifest.sourceTreeDirty -ne $treeDirty -or $manifest.runtimeInputsDirty -ne $runtimeDirty -or
        $manifest.packagingInputsDirty -ne $packagingDirty) {
        throw 'Stage provenance dirty flags do not match source Git state.'
    }
    if ($manifest.packageContentSha256 -notmatch '^[0-9a-f]{64}$') { throw 'Stage provenance has no content fingerprint.' }

    $validator = Join-Path $sourceRoot 'Tools\Test-RetailPackage.ps1'
    & $validator -StagePath $stage -ExpectedInterface '120100'

    function Assert-RejectsMissingReference([string] $relative) {
        $target = [System.IO.Path]::GetFullPath((Join-Path $stage $relative))
        if (-not $target.StartsWith($testFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Fixture path escaped temp stage: $target"
        }
        $held = Join-Path $testRoot ('held-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $target -Destination $held
        try {
            $rejected = $false
            try { & $validator -StagePath $stage -ExpectedInterface '120100' *> $null }
            catch { $rejected = $true }
            if (-not $rejected) { throw "Validator accepted missing reference: $relative" }
        }
        finally { Move-Item -LiteralPath $held -Destination $target }
    }

    Assert-RejectsMissingReference 'Core\Diagnostics.lua' # TOC reference
    Assert-RejectsMissingReference 'Libs\LibStub\LibStub.lua' # XML reference
    Assert-RejectsMissingReference 'Media\Messenger\V3\Alliance\friend.tga' # generated media path

    $luaFixture = Join-Path $stage 'Core\Diagnostics.lua'
    $heldLua = Join-Path $testRoot ('held-' + [guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $luaFixture -Destination $heldLua
    try {
        'function(' | Set-Content -LiteralPath $luaFixture -Encoding utf8
        $rejected = $false
        try { & $validator -StagePath $stage -ExpectedInterface '120100' *> $null }
        catch { $rejected = $true }
        if (-not $rejected) { throw 'Validator accepted malformed staged Lua.' }
    }
    finally {
        Remove-Item -LiteralPath $luaFixture -Force
        Move-Item -LiteralPath $heldLua -Destination $luaFixture
    }
    Write-Host 'Retail package temp-stage mock passed; no live AddOns directory was used.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolved.StartsWith($tempParent + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove package test outside temp: $resolved"
        }
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
