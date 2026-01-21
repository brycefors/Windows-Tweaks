# Run this script in PowerShell

$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$name = "ShowSecondsInSystemClock"
$value = 1

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script enables seconds to be displayed in the system clock on the taskbar."
Write-Host ""
Write-Host "Target Registry Key: $registryPath"
Write-Host "Value to Set:        $name = $value"
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
    Set-ItemProperty -Path $registryPath -Name $name -Value $value -Type DWord -ErrorAction Stop
    Write-Host "Successfully set '$name' to $value." -ForegroundColor Green
    Write-Host "You may need to restart Explorer or sign out for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
} catch {
    Write-Error "Failed to set registry value: $_"
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")