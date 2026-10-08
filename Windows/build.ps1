param([string]$Configuration = 'Release', [string]$DotNet = 'dotnet', [switch]$RunUiTests)
$ErrorActionPreference = 'Stop'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$taskRoot = $PSScriptRoot
$taskVersion = (Get-Content (Join-Path $taskRoot '..\VERSION') -Raw).Trim()
$taskOutput = Join-Path $taskRoot 'artifacts\win-x64'
& $DotNet run --project (Join-Path $taskRoot 'Tests\Tests.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'Windows model tests failed' }
& $DotNet publish (Join-Path $taskRoot 'SearcheXtra\SearcheXtra.csproj') -c $Configuration -r win-x64 -p:Platform=x64 -p:Version=$taskVersion --self-contained true -o $taskOutput
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
if (-not (Test-Path -LiteralPath (Join-Path $taskOutput 'SearcheXtra.pri'))) { throw 'Application XAML resource index missing from publish output' }
& $DotNet publish (Join-Path $taskRoot 'AIWorker\AIWorker.csproj') -c $Configuration -r win-x64 --self-contained true -o (Join-Path $taskOutput 'AIWorker')
if ($LASTEXITCODE -ne 0) { throw 'Local AI worker publish failed' }
if ($RunUiTests) { & (Join-Path $taskRoot 'test-ui.ps1') -Executable (Join-Path $taskOutput 'SearcheXtra.exe') }
$taskArchive = Join-Path $taskRoot "artifacts\SearcheXtra-$taskVersion-win-x64.zip"
Copy-Item -LiteralPath (Join-Path $taskRoot 'README.md') -Destination (Join-Path $taskOutput 'README.md')
Copy-Item -LiteralPath (Join-Path $taskRoot '..\LICENSE') -Destination (Join-Path $taskOutput 'LICENSE')
Compress-Archive -Path (Join-Path $taskOutput '*') -DestinationPath $taskArchive -Force
$taskHash = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $taskRoot 'artifacts\SHA256SUMS.txt') -Value "$taskHash  $(Split-Path $taskArchive -Leaf)" -Encoding ascii
Write-Host "Built Windows 10 1809+ / x86_64: $taskArchive"
