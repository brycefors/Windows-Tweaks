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
Write-Host "This script toggles the High Precision Event Timer (HPET) and"
Write-Host "dynamic ticks."
Write-Host ""
Write-Host "Current State Detection:"
Write-Host "If 'disabledynamictick' is Yes -> Script will REVERT to defaults."
Write-Host "Otherwise                      -> Script will DISABLE HPET."
Write-Host ""
Write-Host "Disable Actions:"
Write-Host "1. bcdedit /deletevalue useplatformclock"
Write-Host "2. bcdedit /set disabledynamictick yes"
Write-Host ""
Write-Host "Revert Actions:"
Write-Host "1. bcdedit /deletevalue disabledynamictick"
Write-Host "2. bcdedit /deletevalue useplatformclock (Ensure default)"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
Write-Host "Checking current BCD state..." -ForegroundColor White
$bcdOutput = cmd /c "bcdedit /enum"
$isDynamicTickDisabled = $bcdOutput -match "disabledynamictick\s+Yes"

if ($isDynamicTickDisabled) {
    Write-Host "Detected: Dynamic Ticks are currently DISABLED (Tweak Applied)." -ForegroundColor Yellow
    Write-Host "Action: Reverting changes (Enabling Dynamic Ticks, Defaulting Platform Clock)." -ForegroundColor White
    
    # Revert logic
    # 1. Allow dynamic ticks (delete value)
    $output1 = cmd /c "bcdedit /deletevalue disabledynamictick 2>&1"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted 'disabledynamictick' (Reverted to default)." -ForegroundColor Green
    } else {
        Write-Warning "Failed to delete 'disabledynamictick': $output1"
    }

    # 2. Ensure platform clock is default (deleted)
    $output2 = cmd /c "bcdedit /deletevalue useplatformclock 2>&1"
    if ($output2 -like "*Element not found*") {
         Write-Host "'useplatformclock' is already default (Element not found)." -ForegroundColor Green
    } elseif ($LASTEXITCODE -eq 0) {
         Write-Host "Successfully deleted 'useplatformclock'." -ForegroundColor Green
    }
    
    Write-Host "HPET/Dynamic Ticks have been re-enabled (restored to defaults)." -ForegroundColor Green
} else {
    Write-Host "Detected: Dynamic Ticks are currently ENABLED (Default)." -ForegroundColor Yellow
    Write-Host "Action: Disabling HPET and Dynamic Ticks." -ForegroundColor White

    # Apply logic
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
}

Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
