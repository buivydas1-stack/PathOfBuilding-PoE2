param(
    [Parameter(Mandatory)][string]$UpstreamZip,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$UpstreamZip = (Resolve-Path -LiteralPath $UpstreamZip).Path
$expectedHash = '7E190D3B66191B09416A9CD4D12394D37DF374D6D6E59AB4F2366F3D9E81BAF7'
if ((Get-FileHash -LiteralPath $UpstreamZip -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Upstream ZIP does not match the official v0.23.1 portable used by this branch.' }
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory; existing files will not be overwritten.' }
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$portablePath = Join-Path $outputPath 'PathOfBuilding-PoE2-v0.23.1-custom.2-Portable'
New-Item -ItemType Directory -Path $portablePath -Force | Out-Null
Expand-Archive -LiteralPath $UpstreamZip -DestinationPath $portablePath
$patches = @('Classes/PowerReportListControl.lua', 'Classes/TreeTab.lua', 'Classes/PassiveTreeView.lua', 'Classes/ConfigTab.lua', 'Classes/CalcsTab.lua', 'Classes/ItemsTab.lua', 'Modules/ConfigOptions.lua', 'Modules/Calcs.lua', 'Modules/CalcOffence.lua', 'Modules/CalcSections.lua', 'Modules/CalcDefence.lua', 'Modules/CalcSetup.lua', 'Modules/ModParser.lua', 'Modules/Build.lua', 'Data/ModRunes.lua', 'Launch.lua', 'Modules/Main.lua')
foreach ($relative in $patches) {
    Copy-Item -LiteralPath (Join-Path $repoPath "src/$relative") -Destination (Join-Path $portablePath $relative)
}
Copy-Item -LiteralPath (Join-Path $repoPath 'CUSTOM-BUILD.md') -Destination $portablePath
Set-Content -LiteralPath (Join-Path $portablePath 'custom.cfg') -Value 'PoB2 custom release; preserve this marker to prevent upstream overwrite.' -Encoding ascii
$commit = & git -c "safe.directory=$($repoPath.Replace('\','/'))" -C $repoPath rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source commit.' }
$dirty = & git -c "safe.directory=$($repoPath.Replace('\','/'))" -C $repoPath status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'Cannot check source status.' }
$metadata = [ordered]@{
    repository = 'buivydas1-stack/PathOfBuilding-PoE2'
    branch = 'codex/pob2-customizations'
    commit = $commit.Trim()
    workingTreeModified = [bool]$dirty
    upstreamVersion = 'v0.23.1'
    upstreamPortableSHA256 = $expectedHash
    changedSourceFiles = $patches
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $portablePath 'custom-build.json') -Encoding utf8

# Verify every preserved file directly against its entry in the official distribution.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($UpstreamZip)
$preserved = 0
try {
    foreach ($entry in $archive.Entries) {
        if (-not $entry.Name -or $patches -contains $entry.FullName) { continue }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $expected = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $stream.Dispose(); $sha.Dispose() }
        $actual = (Get-FileHash -LiteralPath (Join-Path $portablePath $entry.FullName) -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw "Unexpected upstream file modification: $($entry.FullName)" }
        $preserved++
    }
} finally { $archive.Dispose() }
$zipPath = "$portablePath.zip"
[IO.Compression.ZipFile]::CreateFromDirectory($portablePath, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
Set-Content -LiteralPath "$zipPath.sha256" -Value "$hash  $([IO.Path]::GetFileName($zipPath))" -Encoding ascii
Write-Output "Verified $preserved unchanged upstream files."
Write-Output $zipPath
Write-Output "SHA256: $hash"
