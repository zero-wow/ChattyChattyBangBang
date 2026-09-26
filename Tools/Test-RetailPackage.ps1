[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $StagePath,
    [Parameter(Mandatory)] [string] $ExpectedInterface
)

$ErrorActionPreference = 'Stop'
$addonName = 'ChattyChattyBangBang'
if (-not (Test-Path -LiteralPath $StagePath -PathType Container)) {
    throw "Staged addon directory was not found: $StagePath"
}
$stageRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $StagePath).Path).TrimEnd('\')
$stagePrefix = $stageRoot + '\'
$tocPath = Join-Path $stageRoot "$addonName.toc"
if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) { throw "Missing staged TOC: $tocPath" }
if (Test-Path -LiteralPath (Join-Path $stageRoot 'Modules')) {
    throw 'Dormant legacy Modules directory must not be staged for Retail.'
}

function Assert-StagedFile([string] $base, [string] $relative, [string] $referencedBy) {
    $normalized = $relative.Replace('/', '\')
    if ([System.IO.Path]::IsPathRooted($normalized)) {
        throw "Absolute staged reference in ${referencedBy}: $relative"
    }
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $base $normalized))
    if (-not $resolved.StartsWith($stagePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Reference escapes staged addon in ${referencedBy}: $relative"
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Missing staged reference in ${referencedBy}: $relative"
    }
    $script:referenceCount++
    return $resolved
}

$script:referenceCount = 0
$script:xmlCount = 0
$script:visitedXml = @{}
function Test-XmlReferences([string] $xmlPath) {
    if ($script:visitedXml.ContainsKey($xmlPath)) { return }
    $script:visitedXml[$xmlPath] = $true
    $script:xmlCount++
    $document = [System.Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    try { $document.LoadXml((Get-Content -LiteralPath $xmlPath -Raw)) }
    catch { throw "Invalid staged XML $xmlPath : $_" }
    foreach ($node in $document.SelectNodes('//*[@file]')) {
        $relative = $node.GetAttribute('file')
        $dependency = Assert-StagedFile (Split-Path -Parent $xmlPath) $relative $xmlPath
        if ([System.IO.Path]::GetExtension($dependency) -ieq '.xml') {
            Test-XmlReferences $dependency
        }
    }
}

$toc = Get-Content -LiteralPath $tocPath
$interfaceLines = @($toc | Where-Object { $_ -match '^##\s*Interface:\s*(\d+)\s*$' })
if ($interfaceLines.Count -ne 1 -or $interfaceLines[0] -notmatch "^##\s*Interface:\s*$([regex]::Escape($ExpectedInterface))\s*$") {
    throw "Staged TOC does not declare exactly one expected Interface $ExpectedInterface."
}
$iconFound = $false
foreach ($line in $toc) {
    $value = $line.Trim()
    if ($value -match '^##\s*IconTexture:\s*(.+)$') {
        $iconFound = $true
        $texture = $Matches[1].Trim().Replace('/', '\')
        $prefix = "Interface\AddOns\$addonName\"
        if (-not $texture.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "TOC IconTexture must be a staged addon asset: $texture"
        }
        $null = Assert-StagedFile $stageRoot ($texture.Substring($prefix.Length)) $tocPath
    }
    elseif ($value -and -not $value.StartsWith('#')) {
        if ($value -notmatch '\.(lua|xml)$') { throw "Unexpected staged TOC entry: $value" }
        $dependency = Assert-StagedFile $stageRoot $value $tocPath
        if ([System.IO.Path]::GetExtension($dependency) -ieq '.xml') {
            Test-XmlReferences $dependency
        }
    }
}
if (-not $iconFound) { throw 'Staged TOC has no IconTexture reference.' }

# These paths are assembled dynamically in Lua; a plain literal search would
# miss missing faction/state variants. Keep the expected families explicit.
foreach ($faction in @('Alliance', 'Horde')) {
    foreach ($suffix in @('', '-hover', '-pressed')) {
        $null = Assert-StagedFile $stageRoot "Media\Dock\Settings\$faction\config$suffix.tga" 'SmartDock icon family'
    }
}
foreach ($action in @('friend', 'invite', 'local-ignore', 'reply', 'server-ignore')) {
    $null = Assert-StagedFile $stageRoot "Media\Messenger\$action.tga" 'Messenger fallback icon family'
    $null = Assert-StagedFile $stageRoot "Media\Messenger\Horde\$action.tga" 'Messenger fallback icon family'
    foreach ($faction in @('Alliance', 'Horde')) {
        foreach ($suffix in @('', '-hover', '-pressed')) {
            $null = Assert-StagedFile $stageRoot "Media\Messenger\V3\$faction\$action$suffix.tga" 'Messenger V3 icon family'
        }
    }
}

$luac = Get-Command -Name luac -ErrorAction SilentlyContinue
if (-not $luac) { throw 'luac is required to syntax-check staged Lua files.' }
$luaFiles = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File -Filter '*.lua')
if ($luaFiles.Count -eq 0) { throw 'Staged package contains no Lua files.' }
foreach ($file in $luaFiles) {
    & $luac.Source -p $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "Staged Lua syntax check failed: $($file.FullName)" }
}

Write-Host "Validated staged Retail package: $($toc.Count) TOC lines, $($script:xmlCount) referenced XML files, $($luaFiles.Count) Lua files, $($script:referenceCount) file references."
