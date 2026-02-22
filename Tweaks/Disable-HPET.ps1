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

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script disables the High Precision Event Timer (HPET) in Windows"
Write-Host "and disables dynamic ticks to improve system latency."
Write-Host ""
Write-Host "Actions:"
Write-Host "1. bcdedit /deletevalue useplatformclock"
Write-Host "2. bcdedit /set disabledynamictick yes"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
Write-Host "Applying BCD tweaks..." -ForegroundColor White

# 1. useplatformclock
$output1 = cmd /c "bcdedit /deletevalue useplatformclock 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully deleted 'useplatformclock'." -ForegroundColor Green
} elseif ($output1 -like "*Element not found*") {
    Write-Host "'useplatformclock' is already disabled (Element not found)." -ForegroundColor Green
} else {
    Write-Warning "Failed to delete 'useplatformclock': $output1"
}

# 2. disabledynamictick
$output2 = cmd /c "bcdedit /set disabledynamictick yes 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully set 'disabledynamictick' to yes." -ForegroundColor Green
} else {
    Write-Warning "Failed to set 'disabledynamictick': $output2"
}

Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
