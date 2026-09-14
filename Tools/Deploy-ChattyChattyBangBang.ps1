[CmdletBinding()]
param(
    [ValidateSet('Retail')]
    [string] $Target = 'Retail',
    [switch] $StageOnly
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$targets = Import-PowerShellDataFile (Join-Path $sourceRoot 'Packaging\targets.psd1')
$addonName = 'ChattyChattyBangBang'

function Copy-RuntimeTree([string] $stage) {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    # Whitelist runtime inputs so source controls, tests, docs, and future
    # development folders never accidentally become part of an install.
    $runtimeItems = @(
        'ChattyChattyBangBang.lua', 'ChattyChattyBangBang.toc', 'modules.xml',
        'Core', 'Libs', 'Localization', 'Media', 'Modules', 'Providers'
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

foreach ($name in $selectedTargets) {
    $definition = $targets[$name]
    $addOnsRoot = $definition.AddOnsPath
    if (-not (Test-Path -LiteralPath $addOnsRoot -PathType Container)) {
        throw "$name AddOns directory was not found: $addOnsRoot"
    }

    $destination = Join-Path $addOnsRoot $addonName
    # Backups must live outside AddOns. Retail scans every child directory in
    # that folder, and a backup with its own TOC can otherwise be loaded as a
    # second copy of this addon.
    $backupRoot = Join-Path $sourceRoot (Join-Path '.deploy-backups' $name)
    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ccbb-stage-" + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path $stageRoot $addonName
    $backup = $null
    try {
        Copy-RuntimeTree $stage
        Write-ClientToc $stage $definition.Interface
        Apply-ClientPackage $stage $name
        [ordered]@{
            addon = $addonName
            client = $name
            interface = $definition.Interface
            sourceCommit = $gitRevision
            deployedAtUtc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage '.ccbb-deployment.json') -Encoding utf8

        if ($StageOnly) {
            Write-Host "$name staging verified (commit $gitRevision)"
            continue
        }

        if (Test-Path -LiteralPath $destination) {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $backup = Join-Path $backupRoot ("$addonName-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Move-Item -LiteralPath $destination -Destination $backup
        }
        Move-Item -LiteralPath $stage -Destination $destination
        Write-Host "$name deployed to $destination (commit $gitRevision)"
        if ($backup) { Write-Host "Previous install preserved at $backup" }
    }
    finally {
        if (Test-Path -LiteralPath $stageRoot) {
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }
    }
}
