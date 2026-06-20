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
Write-Host "This script disables 8.3 filename (short name) generation on NTFS volumes."
Write-Host ""
Write-Host "8.3 filenames are a legacy format (e.g., PROGRA~1 for Program Files)"
Write-Host "that dates back to DOS. Modern applications rarely use them, but the"
Write-Host "file system still creates them by default, consuming resources."
Write-Host ""
Write-Host "Disabling 8.3 name generation can:"
Write-Host "  - Reduce disk I/O and improve file system performance"
Write-Host "  - Decrease directory lookup time"
Write-Host "  - Save storage overhead"
Write-Host ""
Write-Host "WARNING: Some legacy applications may depend on 8.3 names."
Write-Host "Test thoroughly if you rely on older software."
Write-Host ""
Write-Host "Action:"
Write-Host "1. fsutil behavior set disable8dot3 1"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
Write-Host "Disabling 8.3 filename generation..." -ForegroundColor White

$output = cmd /c "fsutil behavior set disable8dot3 1 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully disabled 8.3 filename generation." -ForegroundColor Green
} else {
    Write-Warning "Failed to disable 8.3 filenames: $output"
}

Write-Host "8.3 filename optimization complete." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
