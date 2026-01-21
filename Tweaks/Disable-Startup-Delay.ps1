# Run this script in PowerShell

$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
$name1 = "StartupDelayInMSec"
$value1 = 0
$name2 = "WaitForIdleState"
$value2 = 0

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script reduces the delay time for startup applications"
Write-Host "and disables waiting for system idle state."
Write-Host ""
Write-Host "Target Registry Key: $registryPath"
Write-Host "Values to Set:"
Write-Host "  1. $name1 = $value1"
Write-Host "  2. $name2 = $value2"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "Created registry path: $registryPath" -ForegroundColor Green
}

try {
    Set-ItemProperty -Path $registryPath -Name $name1 -Value $value1 -Type DWord -ErrorAction Stop
    Write-Host "Successfully set '$name1' to $value1." -ForegroundColor Green

    Set-ItemProperty -Path $registryPath -Name $name2 -Value $value2 -Type DWord -ErrorAction Stop
    Write-Host "Successfully set '$name2' to $value2." -ForegroundColor Green

    Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
} catch {
    Write-Error "Failed to set registry value: $_"
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")