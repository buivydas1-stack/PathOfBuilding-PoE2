# Isolated file fixtures and mocked process calls: never controls the user's PoB.
[CmdletBinding()]
param(
    [string]$TestRoot = (Join-Path ([IO.Path]::GetTempPath()) ('pob-deploy-test-' + [guid]::NewGuid().ToString('N'))),
    [string]$DeploymentScript = (Join-Path $PSScriptRoot 'Deploy-CustomPoB2.ps1')
)
$ErrorActionPreference = 'Stop'
$global:PoBDeployTestRunning = $false
$global:PoBDeployTestStopped = @()
$global:PoBDeployTestStarted = @()
function Get-Process {
    param($Name)
    if ($global:PoBDeployTestRunning) {
        $target = [pscustomobject]@{ Id=111; Path=(Join-Path $install 'Path of Building-PoE2.exe') }
        $target | Add-Member ScriptMethod WaitForExit { param($Timeout) return $true }
        $target
        [pscustomobject]@{ Id=222; Path='C:\OtherPoB\Path of Building-PoE2.exe' }
    }
}
function Stop-Process { param($Id, [switch]$Force) $global:PoBDeployTestStopped += $Id; $global:PoBDeployTestRunning=$false }
function Start-Process { param($FilePath, $WorkingDirectory, $WindowStyle) $global:PoBDeployTestStarted += [pscustomobject]@{ FilePath=$FilePath; WorkingDirectory=$WorkingDirectory; WindowStyle=$WindowStyle } }
function Get-FileHash {
    [CmdletBinding()]
    param([string]$LiteralPath, [string]$Algorithm)
    if ($LiteralPath -match '(?i)[\\/]Builds(?:[\\/]|$)|[\\/]Settings\.xml$') {
        throw 'Deployment must not read saved builds or Settings.xml.'
    }
    Microsoft.PowerShell.Utility\Get-FileHash @PSBoundParameters
}
function Get-ChildItem {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)
    if ($LiteralPath -eq $install -or $LiteralPath -match '(?i)[\\/]Builds(?:[\\/]|$)') {
        throw 'Deployment must not enumerate saved builds.'
    }
    Microsoft.PowerShell.Management\Get-ChildItem @PSBoundParameters
}
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Write-File($Path, $Text) {
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text)
}
function Hash($Path) { (Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Expect-Failure($Block, $Pattern) {
    try { & $Block; throw 'Expected rejection but call succeeded' }
    catch { if ($_.Exception.Message -notmatch $Pattern) { throw } }
}
if (Test-Path -LiteralPath $TestRoot) { throw 'Choose a new test directory.' }
$package = Join-Path $TestRoot 'package'
$install = Join-Path $TestRoot 'install'
$deploy = $DeploymentScript
$metadata = [ordered]@{ repository='buivydas1-stack/PathOfBuilding-PoE2'; commit=('a'*40); workingTreeModified=$false; upstreamVersion='v-test'; upstreamPortableSHA256=('b'*64); changedSourceFiles=@('Modules/Main.lua','Classes/TreeTab.lua','Data/ModRunes.lua') }
foreach ($root in @($package,$install)) {
    Write-File (Join-Path $root 'Path of Building-PoE2.exe') 'test fixture; never executed'
    Write-File (Join-Path $root 'custom.cfg') 'keep custom updater guard'
    Write-File (Join-Path $root 'custom-build.json') ($metadata | ConvertTo-Json)
    Write-File (Join-Path $root 'CUSTOM-BUILD.md') 'same documentation'
    Write-File (Join-Path $root 'Modules/Main.lua') 'same source'
    Write-File (Join-Path $root 'Classes/TreeTab.lua') 'old tree source'
    Write-File (Join-Path $root 'Data/ModRunes.lua') 'old augment data'
}
Write-File (Join-Path $package 'Classes/TreeTab.lua') 'new tree source'
Write-File (Join-Path $package 'Data/ModRunes.lua') 'new augment data'
Write-File (Join-Path $install 'Builds/Nested/Test.xml') '<build>saved user build</build>'
Write-File (Join-Path $install 'Settings.xml') '<settings>user</settings>'
$beforeBuild = Hash (Join-Path $install 'Builds/Nested/Test.xml')
$beforeSettings = Hash (Join-Path $install 'Settings.xml')
$backup = Join-Path $TestRoot 'backup'
$global:PoBDeployTestRunning=$true
$plan = & $deploy -PackageRoot $package -InstallRoot $install
Assert ($plan.Status -eq 'Planned' -and $plan.ChangedFiles.Count -eq 2) 'Plan must list only changed payload'
Assert (-not (Test-Path -LiteralPath $backup) -and $global:PoBDeployTestStopped.Count -eq 0) 'Plan must not write or stop PoB'
$result = & $deploy -PackageRoot $package -InstallRoot $install -BackupRoot $backup -Apply -Restart
Assert ($result.Status -eq 'Installed') 'Installation failed'
Assert ($global:PoBDeployTestStopped.Count -eq 1 -and $global:PoBDeployTestStopped[0] -eq 111) 'Only exact target PoB may be stopped'
Assert ($global:PoBDeployTestStarted.Count -eq 1 -and $global:PoBDeployTestStarted[0].FilePath -eq (Join-Path $install 'Path of Building-PoE2.exe')) 'Restart must target same executable'
Assert ($global:PoBDeployTestStarted[0].WorkingDirectory -eq $install -and $global:PoBDeployTestStarted[0].WindowStyle -eq 'Normal') 'Restart must show the interactive PoB window'
Assert ((Get-Content (Join-Path $backup 'Classes/TreeTab.lua') -Raw) -eq 'old tree source') 'Backup must contain original source'
Assert ((Hash (Join-Path $install 'Classes/TreeTab.lua')) -eq (Hash (Join-Path $package 'Classes/TreeTab.lua'))) 'Payload not installed'
Assert ((Hash (Join-Path $install 'Data/ModRunes.lua')) -eq (Hash (Join-Path $package 'Data/ModRunes.lua'))) 'Augment data not installed'
Assert ((Get-Content (Join-Path $backup 'Data/ModRunes.lua') -Raw) -eq 'old augment data') 'Augment data backup missing'
Assert ((Hash (Join-Path $install 'Builds/Nested/Test.xml')) -eq $beforeBuild) 'Build changed'
Assert ((Hash (Join-Path $install 'Settings.xml')) -eq $beforeSettings) 'Settings changed'
Assert (-not (Test-Path -LiteralPath (Join-Path $backup 'Builds')) -and -not (Test-Path -LiteralPath (Join-Path $backup 'Settings.xml'))) 'User data must not be backed up'
Assert ((Get-Content (Join-Path $backup 'deployment.json') -Raw | ConvertFrom-Json).Status -eq 'Installed') 'Receipt missing'
$again = & $deploy -PackageRoot $package -InstallRoot $install -Apply
Assert ($again.Status -eq 'AlreadyInstalled' -and $global:PoBDeployTestStopped.Count -eq 1) 'No-op must not stop PoB or create backups'

$metadata.commit = 'c'*40
Write-File (Join-Path $package 'custom-build.json') ($metadata | ConvertTo-Json)
$metadataPlan = & $deploy -PackageRoot $package -InstallRoot $install
Assert ($metadataPlan.MetadataOnly -and $metadataPlan.ApplicationChangedFiles.Count -eq 0) 'Stale metadata must not be reported as a changed application'
Assert ($metadataPlan.InstalledCommit -eq 'a'*40 -and $metadataPlan.Commit -eq 'c'*40) 'Plan must distinguish recorded commits'
$global:PoBDeployTestRunning=$true
$metadataResult = & $deploy -PackageRoot $package -InstallRoot $install -BackupRoot (Join-Path $TestRoot 'metadata-backup') -Apply -Restart
Assert ($metadataResult.MetadataOnly -and $global:PoBDeployTestRunning) 'Metadata refresh must leave PoB running'
Assert ($global:PoBDeployTestStopped.Count -eq 1 -and $global:PoBDeployTestStarted.Count -eq 1) 'Metadata refresh must not stop or restart PoB'
Assert ((Get-Content (Join-Path $install 'custom-build.json') -Raw | ConvertFrom-Json).commit -eq 'c'*40) 'Metadata not refreshed'
Assert ((Hash (Join-Path $install 'Builds/Nested/Test.xml')) -eq $beforeBuild -and (Hash (Join-Path $install 'Settings.xml')) -eq $beforeSettings) 'Metadata refresh changed saved data'

$metadata.changedSourceFiles = @('../Settings.xml')
Write-File (Join-Path $package 'custom-build.json') ($metadata | ConvertTo-Json)
Expect-Failure { & $deploy -PackageRoot $package -InstallRoot $install -BackupRoot (Join-Path $TestRoot 'bad-backup') -Apply } 'Unexpected Lua payload'
$metadata.changedSourceFiles = @('Builds/Nested/Test.xml')
Write-File (Join-Path $package 'custom-build.json') ($metadata | ConvertTo-Json)
Expect-Failure { & $deploy -PackageRoot $package -InstallRoot $install -Apply } 'Unexpected Lua payload'
$metadata.changedSourceFiles = @('Modules/Missing.lua')
Write-File (Join-Path $package 'custom-build.json') ($metadata | ConvertTo-Json)
Expect-Failure { & $deploy -PackageRoot $package -InstallRoot $install -Apply } 'Missing file'
$metadata.upstreamVersion = 'different-release'
Write-File (Join-Path $package 'custom-build.json') ($metadata | ConvertTo-Json)
Expect-Failure { & $deploy -PackageRoot $package -InstallRoot $install -Apply } 'Upstream release differs'
Assert ($global:PoBDeployTestStopped.Count -eq 1) 'Invalid packages must be rejected before stopping PoB'
Assert (-not (Test-Path -LiteralPath (Join-Path $TestRoot 'bad-backup'))) 'Invalid package caused writes'
Write-Output "PASS: changed-file deployment, visible restart, metadata refresh without restart, no saved-data scanning/backups, receipt, no-op, invalid-package rejection. Fixtures: $TestRoot"

