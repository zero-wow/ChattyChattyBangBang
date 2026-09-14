[CmdletBinding()]
param(
    [ValidateSet('Retail')]
    [string] $Target = 'Retail',
    [switch] $AllowRunningClient,
    [switch] $StageOnly
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$targets = Import-PowerShellDataFile (Join-Path $sourceRoot 'Packaging\targets.psd1')
$addonName = 'ChattyChattyBangBang'

function Test-WowRunning {
    return @(Get-Process -Name 'Wow', 'WowClassic', 'WorldOfWarcraft' -ErrorAction SilentlyContinue).Count -gt 0
}

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

if (-not $StageOnly -and -not $AllowRunningClient -and (Test-WowRunning)) {
    throw 'A World of Warcraft client is running. Close it before deployment, or pass -AllowRunningClient only if you accept an incomplete install.'
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
    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ccbb-stage-" + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path $stageRoot $addonName
    $backup = $null
    try {
        Copy-RuntimeTree $stage
        Write-ClientToc $stage $definition.Interface
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
            $backup = "$destination.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
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
