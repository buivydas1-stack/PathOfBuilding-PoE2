[CmdletBinding()]
param(
    [string]$PackagingScript = (Join-Path $PSScriptRoot 'Build-CustomPortable.ps1'),
    [string]$BaselineScript,
    [string]$TestRoot = (Join-Path $env:TEMP ('pob-package-test-' + [guid]::NewGuid()))
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $TestRoot) { throw 'Choose a new test directory.' }
$manifestPath = Join-Path $PSScriptRoot 'CustomPortableManifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Invoke-Fixture($Script, $Name, $ExpectEarlyRejection) {
    $fixture = Join-Path $TestRoot $Name
    $repo = Join-Path $fixture 'repo'
    New-Item -ItemType Directory -Path (Join-Path $repo 'tools') -Force | Out-Null
    Copy-Item -LiteralPath $Script -Destination (Join-Path $repo 'tools/Build-CustomPortable.ps1')
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $repo 'tools/CustomPortableManifest.json')
    Set-Content -LiteralPath (Join-Path $repo 'CUSTOM-BUILD.md') -Value 'Packaging fixture'
    foreach ($relative in $manifest.files) {
        $source = Join-Path $repo "src/$relative"
        New-Item -ItemType Directory -Path (Split-Path $source -Parent) -Force | Out-Null
        Set-Content -LiteralPath $source -Value '-- packaging fixture'
    }
    & git -C $repo init --quiet
    if ($LASTEXITCODE) { throw 'Fixture Git init failed.' }
    & git -c core.autocrlf=false -C $repo add .
    if ($LASTEXITCODE) { throw 'Fixture Git add failed.' }
    & git -c user.name=Fixture -c user.email=fixture@example.invalid -C $repo commit --quiet -m fixture
    if ($LASTEXITCODE) { throw 'Fixture Git commit failed.' }
    $builder = Join-Path $repo 'tools/Build-CustomPortable.ps1'
    $cleanStage = Join-Path $fixture 'clean'
    & $builder -Lightweight -OutputDirectory $cleanStage | Out-Null
    foreach ($relative in $manifest.files) {
        Assert ((Get-FileHash -LiteralPath (Join-Path $repo "src/$relative")).Hash -eq (Get-FileHash -LiteralPath (Join-Path $cleanStage $relative)).Hash) "Clean payload mismatch: $relative"
    }
    Assert (-not (Get-Content -LiteralPath (Join-Path $cleanStage 'custom-build.json') -Raw | ConvertFrom-Json).workingTreeModified) 'Clean package marked dirty.'
    Add-Content -LiteralPath (Join-Path $repo "src/$($manifest.files[0])") -Value '-- uncommitted change'
    $dirtyStage = Join-Path $fixture 'dirty'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $rejected = $false
    try { & $builder -Lightweight -OutputDirectory $dirtyStage | Out-Null }
    catch { if ($_.Exception.Message -notmatch 'Commit the source changes before packaging') { throw }; $rejected = $true }
    $watch.Stop()
    $written = if (Test-Path -LiteralPath $dirtyStage) { @(Get-ChildItem -LiteralPath $dirtyStage -File -Recurse).Count } else { 0 }
    Assert ($rejected -eq $ExpectEarlyRejection) 'Unexpected dirty-source acceptance.'
    Assert (($ExpectEarlyRejection -and $written -eq 0) -or (-not $ExpectEarlyRejection -and $written -gt 0)) 'Dirty-package writes did not match expectation.'
    if ($ExpectEarlyRejection) {
        $fullStage = Join-Path $fixture 'full-dirty'
        try { & $builder -UpstreamZip (Join-Path $fixture 'missing.zip') -OutputDirectory $fullStage | Out-Null; throw 'Expected dirty-source rejection.' }
        catch { if ($_.Exception.Message -notmatch 'Commit the source changes before packaging') { throw } }
        Assert (-not (Test-Path -LiteralPath $fullStage)) 'Full packaging wrote before rejection.'
    }
    [pscustomobject]@{ Version=$Name; DirtyPackageFilesWritten=$written; DirtyPackageMilliseconds=[math]::Round($watch.Elapsed.TotalMilliseconds); CleanPayloadFilesVerified=@($manifest.files).Count }
}
if ($BaselineScript) { Invoke-Fixture $BaselineScript 'Before' $false }
Invoke-Fixture $PackagingScript 'After' $true
