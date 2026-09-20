param([string]$DeploymentScript = (Join-Path $PSScriptRoot 'Deploy-CustomPoB2.ps1'))
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('pob-deploy-test-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $root 'package'; $install = Join-Path $root 'install'
foreach ($dir in @($package, $install)) {
    New-Item -ItemType Directory -Path (Join-Path $dir 'Modules') -Force | Out-Null
    Set-Content (Join-Path $dir 'CUSTOM-BUILD.md') 'fixture'
}
Set-Content (Join-Path $install 'Path of Building-PoE2.exe') 'fixture only; never launched'
$exeHash = (Get-FileHash (Join-Path $install 'Path of Building-PoE2.exe')).Hash
$meta = @{repository='buivydas1-stack/PathOfBuilding-PoE2'; workingTreeModified=$false; commit=('a'*40); upstreamVersion='fixture'; upstreamPortableSHA256='fixture'; changedSourceFiles=@('Modules/Build.lua'); executableSHA256=$exeHash}
foreach ($dir in @($package, $install)) { $meta | ConvertTo-Json | Set-Content (Join-Path $dir 'custom-build.json') }
Set-Content (Join-Path $package 'Modules/Build.lua') 'new application'
Set-Content (Join-Path $install 'Modules/Build.lua') 'old application'
Set-Content (Join-Path $install 'custom.cfg') 'keep marker'
Set-Content (Join-Path $install 'Settings.xml') 'saved settings'
New-Item -ItemType Directory -Path (Join-Path $install 'Builds') | Out-Null
Set-Content (Join-Path $install 'Builds/test.xml') 'saved tree'
$protected = @{}
foreach ($f in @('Settings.xml','custom.cfg','Builds/test.xml')) { $protected[$f] = (Get-FileHash (Join-Path $install $f)).Hash }
$plan = & $DeploymentScript -PackageRoot $package -InstallRoot $install
if ($plan.Status -ne 'Planned') { throw 'Expected lightweight plan' }
$meta.executableSHA256 = '0'*64
$meta | ConvertTo-Json | Set-Content (Join-Path $package 'custom-build.json')
$rejected = $false
try { & $DeploymentScript -PackageRoot $package -InstallRoot $install | Out-Null } catch { if ($_.Exception.Message -notlike 'Executable differs*') { throw }; $rejected=$true }
if (-not $rejected) { throw 'Mismatched executable accepted' }
$meta.executableSHA256 = $exeHash
$meta | ConvertTo-Json | Set-Content (Join-Path $package 'custom-build.json')
$backup = Join-Path $root 'backup'
$result = & $DeploymentScript -PackageRoot $package -InstallRoot $install -BackupRoot $backup -Apply
if ($result.Status -ne 'Installed') { throw 'Lightweight deployment failed' }
foreach ($f in $protected.Keys) {
    if ((Get-FileHash (Join-Path $install $f)).Hash -ne $protected[$f]) { throw "Protected data changed: $f" }
    if (Test-Path (Join-Path $backup $f)) { throw "Unexpected user-data backup: $f" }
}
if ((Get-Content (Join-Path $backup 'Modules/Build.lua') -Raw).Trim() -ne 'old application') { throw 'Application rollback copy missing' }
if ((& $DeploymentScript -PackageRoot $package -InstallRoot $install -Apply).Status -ne 'AlreadyInstalled') { throw 'No-op detection failed' }
# Compatibility with existing full portable packages lacking the new hash field.
Copy-Item (Join-Path $install 'Path of Building-PoE2.exe') $package
$meta.Remove('executableSHA256')
$meta | ConvertTo-Json | Set-Content (Join-Path $package 'custom-build.json')
if ((& $DeploymentScript -PackageRoot $package -InstallRoot $install).Status -ne 'Planned') { throw 'Legacy package rejected' }
Write-Output 'PASS: lightweight apply, executable mismatch, no-op, legacy package, saved-data preservation and application-only backup.'
