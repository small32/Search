param([ValidateSet('DotNet', 'AppSdk', 'WebView2')][string]$Runtime)
$ErrorActionPreference = 'Stop'
try {
    switch ($Runtime) {
        'DotNet' {
            # The application's runtimeconfig requests 8.0.0 and rolls forward to installed 8.0 patches.
            $locations = @("$env:ProgramFiles\dotnet")
            foreach ($key in @('HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64',
                              'HKLM:\SOFTWARE\WOW6432Node\dotnet\Setup\InstalledVersions\x64')) {
                $location = (Get-ItemProperty $key -ErrorAction SilentlyContinue).InstallLocation
                if ($location) { $locations += $location }
            }
            foreach ($location in ($locations | Select-Object -Unique)) {
                foreach ($directory in (Get-ChildItem "$location\shared\Microsoft.NETCore.App" -Directory -ErrorAction SilentlyContinue)) {
                    $version = $null
                    if ([version]::TryParse($directory.Name, [ref]$version) -and $version.Major -eq 8 -and
                        (Test-Path "$($directory.FullName)\coreclr.dll")) { exit 0 }
                }
            }
        }
        'AppSdk' {
            $package = Get-AppxPackage -Name Microsoft.WindowsAppRuntime.1.8 |
                Where-Object { $_.Architecture -eq 'X64' -and [version]$_.Version -ge [version]'8000.994.2142.0' }
            if ($package) { exit 0 }
        }
        'WebView2' {
            $client = 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
            foreach ($path in @("HKLM:\$($client.Replace('SOFTWARE\', 'SOFTWARE\WOW6432Node\'))", "HKCU:\$client")) {
                $version = $null
                $value = (Get-ItemProperty $path -ErrorAction SilentlyContinue).pv
                if ([version]::TryParse($value, [ref]$version) -and $version -gt [version]'0.0.0.0') { exit 0 }
            }
        }
    }
    exit 1
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 2
}
