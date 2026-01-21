# Run this script in PowerShell
# Auto-elevates to Administrator if run as a standard user.

# --- AUTO-ELEVATION BLOCK ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Elevating..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
    $processInfo.Verb = "RunAs"
    $process = [System.Diagnostics.Process]::Start($processInfo)
    exit
}

$telemetryKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$advertisingKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script disables Windows Telemetry and Data Collection."
Write-Host ""
Write-Host "Actions:"
Write-Host "1. Sets 'AllowTelemetry' to 0 (Security level)."
Write-Host "2. Disables Advertising ID."
Write-Host "3. Stops and disables 'DiagTrack' (Connected User Experiences)."
Write-Host "4. Stops and disables 'dmwappushservice'."
Write-Host ""
Write-Host "NOTE: Intune may not work correctly in enterprise environments." -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic

# 1. Registry: AllowTelemetry
if (-not (Test-Path $telemetryKey)) {
    New-Item -Path $telemetryKey -Force | Out-Null
}
try {
    Set-ItemProperty -Path $telemetryKey -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction Stop
    Write-Host "Successfully set AllowTelemetry to 0." -ForegroundColor Green
} catch {
    Write-Error "Failed to set AllowTelemetry: $_"
}

# 2. Registry: Advertising ID
if (-not (Test-Path $advertisingKey)) {
    New-Item -Path $advertisingKey -Force | Out-Null
}
try {
    Set-ItemProperty -Path $advertisingKey -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -ErrorAction Stop
    Write-Host "Successfully disabled Advertising ID." -ForegroundColor Green
} catch {
    Write-Error "Failed to disable Advertising ID: $_"
}

# 3. Services
$services = @("DiagTrack", "dmwappushservice")
foreach ($service in $services) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
            Write-Host "Successfully disabled service: $service" -ForegroundColor Green
        } else {
            Write-Warning "Service not found: $service"
        }
    } catch {
        Write-Error "Failed to disable service $service : $_"
    }
}

Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")