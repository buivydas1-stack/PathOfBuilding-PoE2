param(
    [string]$UpstreamZip,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$Lightweight
)
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'CustomPortableManifest.json') -Raw | ConvertFrom-Json
$expectedHash = $manifest.upstreamPortableSHA256
$patches = @($manifest.files)
if (-not $patches.Count -or @($patches | Sort-Object -Unique).Count -ne $patches.Count) { throw 'Invalid payload manifest.' }
foreach ($relative in $patches) {
    if ($relative -notmatch '^(?:(?:Classes|Modules|Data)/[A-Za-z0-9_/-]+\.lua|Launch\.lua)$' -or $relative -match '\.\.') { throw "Invalid payload path: $relative" }
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath "src/$relative") -PathType Leaf)) { throw "Missing source: $relative" }
}
if (-not $Lightweight) {
    if (-not $UpstreamZip) { throw '-UpstreamZip is required for full packaging.' }
    $UpstreamZip = (Resolve-Path -LiteralPath $UpstreamZip).Path
    if ((Get-FileHash -LiteralPath $UpstreamZip -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Upstream ZIP does not match the manifest.' }
}
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory; existing files will not be overwritten.' }
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$portablePath = if ($Lightweight) { $outputPath } else { Join-Path $outputPath $manifest.portableDirectory }
New-Item -ItemType Directory -Path $portablePath -Force | Out-Null
if (-not $Lightweight) { Expand-Archive -LiteralPath $UpstreamZip -DestinationPath $portablePath }
foreach ($relative in $patches) {
    New-Item -ItemType Directory -Path (Split-Path (Join-Path $portablePath $relative) -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoPath "src/$relative") -Destination (Join-Path $portablePath $relative)
}
Copy-Item -LiteralPath (Join-Path $repoPath 'CUSTOM-BUILD.md') -Destination $portablePath
if (-not $Lightweight) {
    if ((Get-FileHash -LiteralPath (Join-Path $portablePath 'Path of Building-PoE2.exe')).Hash -ne $manifest.executableSHA256) { throw 'Executable does not match manifest.' }
    Set-Content -LiteralPath (Join-Path $portablePath 'custom.cfg') -Value 'PoB2 custom release; preserve this marker to prevent upstream overwrite.' -Encoding ascii
}
$commit = & git -c "safe.directory=$($repoPath.Replace('\','/'))" -C $repoPath rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source commit.' }
$dirty = & git -c "safe.directory=$($repoPath.Replace('\','/'))" -C $repoPath status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'Cannot check source status.' }
$metadata = [ordered]@{
    repository = 'buivydas1-stack/PathOfBuilding-PoE2'
    branch = 'codex/pob2-customizations'
    commit = $commit.Trim()
    workingTreeModified = [bool]$dirty
    upstreamVersion = $manifest.upstreamVersion
    executableSHA256 = $manifest.executableSHA256
    packageKind = $(if ($Lightweight) { 'lua-overlay' } else { 'portable' })
    upstreamPortableSHA256 = $expectedHash
    changedSourceFiles = $patches
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $portablePath 'custom-build.json') -Encoding utf8

# Verify the staged payload in both modes.
foreach ($relative in $patches) {
    if ((Get-FileHash -LiteralPath (Join-Path $repoPath "src/$relative")).Hash -ne (Get-FileHash -LiteralPath (Join-Path $portablePath $relative)).Hash) { throw "Staging mismatch: $relative" }
}
if ($Lightweight) { Write-Output "Staged $($patches.Count) custom Lua files: $portablePath"; return }

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
