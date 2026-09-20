<#
.SYNOPSIS
Back up and deploy a custom PoB2 Lua payload over the same portable upstream release.
.DESCRIPTION
Without -Apply, validates and returns a read-only plan, even while PoB is running.
With -Apply, stops only the exact target PoB executable WITHOUT SAVING, per the
user's deployment preference. Saved builds/settings are preserved without backup; unsaved edits are lost.
Use -Restart to launch the same executable after a verified deployment.
No network access, Git writes, upstream upgrade, user-data replacement or deletion.
.EXAMPLE
./Deploy-PoB2.ps1 -PackageRoot 'D:/staging/portable' -InstallRoot 'C:/Apps/PoB2'
.EXAMPLE
./Deploy-PoB2.ps1 -PackageRoot 'D:/staging/portable' -InstallRoot 'C:/Apps/PoB2' -BackupRoot 'D:/backups/pob-update-001' -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [Parameter(Mandatory)][string]$InstallRoot,
    [string]$BackupRoot,
    [switch]$Apply,
    [switch]$Restart
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CheckedPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Use a physical path, not a link or junction: $cursor"
            }
        }
        $parent = Split-Path -Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    return $full.TrimEnd('\', '/')
}
function Get-ChildPath([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Contains(':')) {
        throw "Expected a relative payload path: $Relative"
    }
    $full = Get-CheckedPath (Join-Path $Root $Relative)
    if (-not $full.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes root: $Relative"
    }
    return $full
}
function Get-Hash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Test-Overlap([string]$Left, [string]$Right) {
    return $Left.Equals($Right, [StringComparison]::OrdinalIgnoreCase) -or
        $Left.StartsWith($Right + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        $Right.StartsWith($Left + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Get-TargetProcesses {
    foreach ($process in @(Get-Process -Name 'Path of Building-PoE2' -ErrorAction SilentlyContinue)) {
        if (-not $process.Path) { throw 'Cannot identify a PoB executable path; do not kill an unidentified process.' }
        if ($process.Path.Equals($targetExe, [StringComparison]::OrdinalIgnoreCase)) {
            $process
        }
    }
}

$package = Get-CheckedPath $PackageRoot
$install = Get-CheckedPath $InstallRoot
foreach ($root in @($package, $install)) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Missing directory: $root" }
}
if (Test-Overlap $package $install) { throw 'Package and installation must be separate directories.' }
$metadata = Get-Content -LiteralPath (Get-ChildPath $package 'custom-build.json') -Raw | ConvertFrom-Json
$installedMetadata = Get-Content -LiteralPath (Get-ChildPath $install 'custom-build.json') -Raw | ConvertFrom-Json
if ($metadata.repository -ne 'buivydas1-stack/PathOfBuilding-PoE2' -or $installedMetadata.repository -ne $metadata.repository) {
    throw 'Unexpected custom fork metadata.'
}
if ($metadata.workingTreeModified -or $metadata.commit -notmatch '^[a-f0-9]{40}$') { throw 'Build a clean committed package first.' }
if ($metadata.upstreamVersion -ne $installedMetadata.upstreamVersion -or
    $metadata.upstreamPortableSHA256 -ne $installedMetadata.upstreamPortableSHA256) {
    throw 'Upstream release differs. This helper only deploys same-release customizations.'
}
$targetExe = Get-ChildPath $install 'Path of Building-PoE2.exe'
# New stages record the pinned executable hash; older full packages remain usable.
if ($metadata.PSObject.Properties['executableSHA256']) {
    $expectedExeHash = $metadata.executableSHA256
    if ($expectedExeHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid executable hash in metadata.' }
    $packageExe = Get-ChildPath $package 'Path of Building-PoE2.exe'
    if ((Test-Path -LiteralPath $packageExe) -and (Get-Hash $packageExe) -ne $expectedExeHash) { throw 'Package executable differs from metadata.' }
} else {
    $expectedExeHash = Get-Hash (Get-ChildPath $package 'Path of Building-PoE2.exe')
}
if ((Get-Hash $targetExe) -ne $expectedExeHash) {
    throw 'Executable differs from the expected upstream runtime; verify the target installation.'
}
$null = Get-Hash (Get-ChildPath $install 'custom.cfg')
$payload = @($metadata.changedSourceFiles)
if (-not $payload.Count) { throw 'Package has no custom payload manifest.' }
foreach ($relative in $payload) {
    if ($relative -notmatch '^(?:(?:Classes|Modules|Data)/[A-Za-z0-9_/-]+\.lua|Launch\.lua)$' -or $relative -match '\.\.') {
        throw "Unexpected Lua payload path: $relative"
    }
}
$payload += @('CUSTOM-BUILD.md', 'custom-build.json')
if (@($payload | Sort-Object -Unique).Count -ne $payload.Count) { throw 'Duplicate payload paths.' }
$plan = @(foreach ($relative in $payload) {
    $source = Get-ChildPath $package $relative
    $destination = Get-ChildPath $install $relative
    $newHash = Get-Hash $source
    $oldHash = if (Test-Path -LiteralPath $destination -PathType Leaf) { Get-Hash $destination } else { $null }
    [pscustomobject]@{ Path=$relative; Before=$oldHash; After=$newHash; Changed=($newHash -ne $oldHash) }
})
$changed = @($plan | Where-Object Changed)
if (-not $Apply -or -not $changed.Count) {
    [pscustomobject]@{ Status=$(if ($changed.Count) {'Planned'} else {'AlreadyInstalled'}); Commit=$metadata.commit; ChangedFiles=@($changed | ForEach-Object Path); InstallRoot=$install }
    return
}
if (-not $BackupRoot) { throw '-BackupRoot is required with -Apply.' }
$backup = Get-CheckedPath $BackupRoot
if ((Test-Overlap $backup $package) -or (Test-Overlap $backup $install) -or (Test-Path -LiteralPath $backup)) {
    throw 'Choose a new backup directory outside the package and installation.'
}
foreach ($process in @(Get-TargetProcesses)) {
    Stop-Process -Id $process.Id -Force -ErrorAction Stop
    if (-not $process.WaitForExit(10000)) { throw 'Target PoB did not exit; no files copied.' }
}

# Hash portable user data for preservation checks; do not back it up or replace it.
$userData = @('Settings.xml', 'custom.cfg')
$buildDir = Get-ChildPath $install 'Builds'
if (Test-Path -LiteralPath $buildDir) {
    $directories = [Collections.Generic.Queue[string]]::new()
    $directories.Enqueue($buildDir)
    while ($directories.Count) {
        foreach ($entry in Get-ChildItem -LiteralPath $directories.Dequeue() -Force) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked build data requires explicit handling: $($entry.FullName)" }
            if ($entry.PSIsContainer) { $directories.Enqueue($entry.FullName) }
            else { $userData += $entry.FullName.Substring($install.Length + 1) }
        }
    }
}
$protected = @(foreach ($relative in $userData) {
    $path = Get-ChildPath $install $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) { [pscustomobject]@{ Path=$relative; SHA256=(Get-Hash $path) } }
})
New-Item -ItemType Directory -Path $backup | Out-Null
foreach ($relative in @($changed | Where-Object Before | ForEach-Object Path | Sort-Object -Unique)) {
    $destination = Get-ChildPath $backup $relative
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Get-ChildPath $install $relative) -Destination $destination
    if ((Get-Hash $destination) -ne (Get-Hash (Get-ChildPath $install $relative))) { throw "Backup mismatch: $relative" }
}
$receipt = [ordered]@{ Status='BackedUp'; Commit=$metadata.commit; InstallRoot=$install; PackageRoot=$package; Files=$plan; Protected=$protected; UTC=[DateTime]::UtcNow.ToString('o') }
$receiptPath = Join-Path $backup 'deployment.json'
$receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding utf8
try {
    if (@(Get-TargetProcesses).Count) { throw 'Target PoB reopened during backup; no deployment attempted.' }
    foreach ($file in $changed) {
        $destination = Get-ChildPath $install $file.Path
        $currentHash = if (Test-Path -LiteralPath $destination) { Get-Hash $destination } else { $null }
        if ($currentHash -ne $file.Before) { throw "Target changed after planning: $($file.Path)" }
        if ((Get-Hash (Get-ChildPath $package $file.Path)) -ne $file.After) { throw "Package changed after planning: $($file.Path)" }
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Get-ChildPath $package $file.Path) -Destination $destination
    }
    foreach ($file in $plan) {
        if ((Get-Hash (Get-ChildPath $install $file.Path)) -ne $file.After) { throw "Installed hash mismatch: $($file.Path)" }
    }
    foreach ($file in $protected) {
        if ((Get-Hash (Get-ChildPath $install $file.Path)) -ne $file.SHA256) { throw "User data changed: $($file.Path)" }
    }
    $receipt.Status = 'Installed'
} catch {
    $receipt.Status = 'Failed'
    $receipt['Error'] = $_.Exception.Message
    throw "Deployment stopped; inspect $receiptPath and the backup before retrying. $($_.Exception.Message)"
} finally {
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding utf8
}
if ($Restart) { Start-Process -FilePath $targetExe -WorkingDirectory $install -WindowStyle Hidden }
[pscustomobject]@{ Status='Installed'; Commit=$metadata.commit; ChangedFiles=@($changed | ForEach-Object Path); BackupRoot=$backup; Receipt=$receiptPath }
