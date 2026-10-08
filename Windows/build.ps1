param([string]$Configuration = 'Release', [string]$DotNet = 'dotnet', [switch]$RunUiTests,
      [string]$InnoSetupCompiler = '')
$ErrorActionPreference = 'Stop'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$taskRoot = $PSScriptRoot
$taskVersion = (Get-Content (Join-Path $taskRoot '..\VERSION') -Raw).Trim()
$taskOutput = [IO.Path]::GetFullPath((Join-Path $taskRoot 'artifacts\win-x64'))
$taskArtifacts = [IO.Path]::GetFullPath((Join-Path $taskRoot 'artifacts'))
if ([IO.Path]::GetDirectoryName($taskOutput) -ne $taskArtifacts) { throw 'Publish output must be inside Windows/artifacts' }
& $DotNet run --project (Join-Path $taskRoot 'Tests\Tests.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'Windows model tests failed' }
if (Test-Path -LiteralPath $taskOutput) { Remove-Item -LiteralPath $taskOutput -Recurse -Force }
& $DotNet publish (Join-Path $taskRoot 'SearcheXtra\SearcheXtra.csproj') -c $Configuration -r win-x64 -p:Platform=x64 --self-contained false -p:WindowsAppSDKSelfContained=false -p:DebugType=None -o $taskOutput
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
if (-not (Test-Path -LiteralPath (Join-Path $taskOutput 'SearcheXtra.pri'))) { throw 'Application XAML resource index missing from publish output' }
foreach ($taskExcluded in @('coreclr.dll', 'hostfxr.dll', 'Microsoft.UI.Xaml.dll', 'SearcheXtra.AIWorker.exe', 'Microsoft.Windows.AI.Projection.dll', 'Microsoft.Windows.AI.MachineLearning.Projection.dll')) {
    if (Test-Path -LiteralPath (Join-Path $taskOutput $taskExcluded)) { throw "Unexpected bundled component: $taskExcluded" }
}
if ($RunUiTests) { & (Join-Path $taskRoot 'test-ui.ps1') -Executable (Join-Path $taskOutput 'SearcheXtra.exe') }
$taskArchive = Join-Path $taskRoot "artifacts\SearcheXtra-$taskVersion-win-x64.zip"
Copy-Item -LiteralPath (Join-Path $taskRoot 'README.md') -Destination (Join-Path $taskOutput 'README.md')
Copy-Item -LiteralPath (Join-Path $taskRoot '..\LICENSE') -Destination (Join-Path $taskOutput 'LICENSE')
Compress-Archive -Path (Join-Path $taskOutput '*') -DestinationPath $taskArchive -Force
if (-not $InnoSetupCompiler) {
    $taskCompiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($taskCompiler) { $InnoSetupCompiler = $taskCompiler.Source }
    else {
        foreach ($taskCandidate in @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:LOCALAPPDATA\SearcheXtraBuild\InnoSetupPortable\tools\ISCC.exe")) {
            if (Test-Path -LiteralPath $taskCandidate) { $InnoSetupCompiler = $taskCandidate; break }
        }
    }
}
if (-not $InnoSetupCompiler) { throw 'Install Inno Setup 6.7+ or supply -InnoSetupCompiler with the path to ISCC.exe.' }
& $InnoSetupCompiler "/DAppVersion=$taskVersion" (Join-Path $taskRoot 'Installer\setup.iss')
if ($LASTEXITCODE -ne 0) { throw 'Windows installer build failed' }
$taskInstaller = Join-Path $taskArtifacts "SearcheXtra-$taskVersion-win-x64-setup.exe"
$taskHashes = foreach ($taskFile in @($taskArchive, $taskInstaller)) {
    "$((Get-FileHash -LiteralPath $taskFile -Algorithm SHA256).Hash.ToLowerInvariant())  $(Split-Path $taskFile -Leaf)"
}
Set-Content -LiteralPath (Join-Path $taskRoot 'artifacts\SHA256SUMS.txt') -Value $taskHashes -Encoding ascii
# Replacing an installer at the same path can leave Explorer showing its old icon.
if (-not ('SearcheXtra.BuildShell' -as [type])) {
    Add-Type -Namespace SearcheXtra -Name BuildShell -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern void SHChangeNotify(int eventId, uint flags, string path, System.IntPtr unused);
'@
}
[SearcheXtra.BuildShell]::SHChangeNotify(0x2000, 0x2005, $taskInstaller, [IntPtr]::Zero)
Write-Host "Built Windows 10 1809+ / x86_64: $taskArchive"
