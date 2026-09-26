[CmdletBinding()]
param(
    [ValidateSet('Retail')]
    [string] $Target = 'Retail',
    [switch] $StageOnly,
    [string] $StageOutputRoot
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$targets = Import-PowerShellDataFile (Join-Path $sourceRoot 'Packaging\targets.psd1')
$addonName = 'ChattyChattyBangBang'
$validator = Join-Path $PSScriptRoot 'Test-RetailPackage.ps1'

if ($StageOutputRoot -and -not $StageOnly) {
    throw '-StageOutputRoot is only valid with -StageOnly.'
}

function Assert-ChildPath([string] $path, [string] $parent) {
    $full = [System.IO.Path]::GetFullPath($path)
    $prefix = [System.IO.Path]::GetFullPath($parent).TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside its expected parent: $full"
    }
}

function Copy-RuntimeTree([string] $stage) {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    # Whitelist runtime inputs so source controls, tests, docs, and future
    # development folders never accidentally become part of an install.
    $runtimeItems = @(
        'ChattyChattyBangBang.lua', 'ChattyChattyBangBang.toc', 'modules.xml',
        'Core', 'Libs', 'Localization', 'Media', 'Providers'
    )
    foreach ($item in $runtimeItems) {
        $source = Join-Path $sourceRoot $item
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Required runtime input is missing: $source"
        }
        Copy-Item -LiteralPath $source -Destination $stage -Recurse -Force
    }
}

function Write-ClientToc([string] $stage, [string] $interface) {
    $tocPath = Join-Path $stage "$addonName.toc"
    $toc = Get-Content -LiteralPath $tocPath
    $toc = $toc -replace '^## Interface:.*$', "## Interface: $interface"
    Set-Content -LiteralPath $tocPath -Value $toc -Encoding utf8
}

function Apply-ClientPackage([string] $stage, [string] $client) {
    if ($client -ne 'Retail') { return }

    # The Modules folder is copied legacy Chatter functionality. It mutates
    # retired native chat frames and several modules initialize those obsolete
    # APIs even when their preference is disabled. Smart Chat's Core owns the
    # live Retail experience, so generate an intentionally empty legacy module
    # manifest for Retail while retaining the original manifest for 3.3.5.
    $modulesPath = Join-Path $stage 'modules.xml'
    @(
        '<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/ ..\FrameXML\UI.xsd">',
        '    <!-- Retail uses Smart Chat Core; legacy native-frame modules are intentionally omitted. -->',
        '</Ui>'
    ) | Set-Content -LiteralPath $modulesPath -Encoding utf8
}

$selectedTargets = @($Target)
$gitRevision = (git -C $sourceRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $gitRevision) { throw 'Could not identify source Git HEAD.' }
$sourceTreeDirty = @(git -C $sourceRoot status --porcelain --untracked-files=all).Count -gt 0
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect source Git status.' }
$runtimeInputs = @('ChattyChattyBangBang.lua', 'ChattyChattyBangBang.toc', 'modules.xml',
    'Core', 'Libs', 'Localization', 'Media', 'Providers')
$runtimeInputsDirty = @(git -C $sourceRoot status --porcelain --untracked-files=all -- $runtimeInputs).Count -gt 0
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect runtime input status.' }
$packagingInputs = @('Tools/Deploy-ChattyChattyBangBang.ps1', 'Tools/Test-RetailPackage.ps1',
    'Packaging/targets.psd1')
$packagingInputsDirty = @(git -C $sourceRoot status --porcelain --untracked-files=all -- $packagingInputs).Count -gt 0
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect packaging input status.' }

function Get-StageContentHash([string] $stage) {
    $entries = foreach ($file in (Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
        "$relative $((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

foreach ($name in $selectedTargets) {
    $definition = $targets[$name]
    $addOnsRoot = $definition.AddOnsPath
    if (-not $StageOnly -and -not (Test-Path -LiteralPath $addOnsRoot -PathType Container)) {
        throw "$name AddOns directory was not found: $addOnsRoot"
    }

    $stageDestination = $null
    if ($StageOutputRoot) {
        if (-not (Test-Path -LiteralPath $StageOutputRoot -PathType Container)) {
            throw "Stage output directory was not found: $StageOutputRoot"
        }
        $outputFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $StageOutputRoot).Path)
        $liveFull = [System.IO.Path]::GetFullPath($addOnsRoot)
        $livePrefix = $liveFull.TrimEnd('\') + '\'
        if ($outputFull.TrimEnd('\') -eq $liveFull.TrimEnd('\') -or
            $outputFull.StartsWith($livePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Stage output must not be inside the live Retail AddOns directory.'
        }
        $stageDestination = Join-Path $outputFull $addonName
        Assert-ChildPath $stageDestination $outputFull
        if (Test-Path -LiteralPath $stageDestination) {
            throw "Stage output already exists; refusing to overwrite: $stageDestination"
        }
    }

    $destination = Join-Path $addOnsRoot $addonName
    # Backups must live outside AddOns. Retail scans every child directory in
    # that folder, and a backup with its own TOC can otherwise be loaded as a
    # second copy of this addon.
    $backupRoot = Join-Path $sourceRoot (Join-Path '.deploy-backups' $name)
    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ccbb-stage-" + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path $stageRoot $addonName
    Assert-ChildPath $destination $addOnsRoot
    Assert-ChildPath $backupRoot $sourceRoot
    Assert-ChildPath $stageRoot ([System.IO.Path]::GetTempPath())
    Assert-ChildPath $stage $stageRoot
    $backup = $null
    try {
        Copy-RuntimeTree $stage
        Write-ClientToc $stage $definition.Interface
        Apply-ClientPackage $stage $name
        & $validator -StagePath $stage -ExpectedInterface $definition.Interface
        if (-not $?) { throw 'Staged Retail package validation failed.' }
        $contentHash = Get-StageContentHash $stage
        [ordered]@{
            addon = $addonName
            client = $name
            interface = $definition.Interface
            sourceCommit = $gitRevision
            sourceTreeDirty = $sourceTreeDirty
            runtimeInputsDirty = $runtimeInputsDirty
            packagingInputsDirty = $packagingInputsDirty
            packageContentSha256 = $contentHash
            packagedAtUtc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage '.ccbb-deployment.json') -Encoding utf8

        $sourceLabel = if ($sourceTreeDirty) { "$gitRevision + uncommitted changes" } else { $gitRevision }

        if ($StageOnly) {
            if ($stageDestination) {
                Move-Item -LiteralPath $stage -Destination $stageDestination
                Write-Host "$name staging verified at $stageDestination (source $sourceLabel)"
            }
            else {
                Write-Host "$name staging verified (source $sourceLabel)"
            }
            continue
        }

        if (Test-Path -LiteralPath $destination) {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $backup = Join-Path $backupRoot ("$addonName-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Assert-ChildPath $backup $backupRoot
            Move-Item -LiteralPath $destination -Destination $backup
        }
        Move-Item -LiteralPath $stage -Destination $destination
        Write-Host "$name deployed to $destination (source $sourceLabel)"
        if ($backup) { Write-Host "Previous install preserved at $backup" }
    }
    finally {
        if (Test-Path -LiteralPath $stageRoot) {
            Assert-ChildPath $stageRoot ([System.IO.Path]::GetTempPath())
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }
    }
}
