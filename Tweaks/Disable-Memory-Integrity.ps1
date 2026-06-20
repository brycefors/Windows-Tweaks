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

$memoryIntegrityKey = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script turns off Memory Integrity (Core Isolation) in Windows Security."
Write-Host ""
Write-Host "Actions:"
Write-Host "1. Sets the HVCI Memory Integrity registry value to 0."
Write-Host "2. Requires a reboot to fully apply the change."
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
try {
    if (-not (Test-Path $memoryIntegrityKey)) {
        New-Item -Path $memoryIntegrityKey -Force | Out-Null
    }

    $currentValue = Get-ItemProperty -Path $memoryIntegrityKey -Name "Enabled" -ErrorAction SilentlyContinue
    if ($null -ne $currentValue -and $currentValue.Enabled -eq 0) {
        Write-Host "Memory Integrity is already disabled." -ForegroundColor Green
    } else {
        Set-ItemProperty -Path $memoryIntegrityKey -Name "Enabled" -Value 0 -Type DWord -ErrorAction Stop
        Write-Host "Successfully disabled Memory Integrity." -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to disable Memory Integrity: $_"
}

Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")