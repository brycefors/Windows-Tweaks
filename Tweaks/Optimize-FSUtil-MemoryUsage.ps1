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
Write-Host "This script optimizes file system memory usage for better performance."
Write-Host ""
Write-Host "The 'memoryusage' setting controls how the file system driver allocates"
Write-Host "memory for the file system cache:"
Write-Host "  0 = Default (minimal memory usage)"
Write-Host "  1 = Moderate memory usage"
Write-Host "  2 = Maximum memory usage (optimal performance)"
Write-Host ""
Write-Host "Setting this to 2 allows Windows to use more memory for file caching,"
Write-Host "which can improve disk I/O performance."
Write-Host ""
Write-Host "Action:"
Write-Host "1. fsutil behavior set memoryusage 2"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
Write-Host "Applying FSUtil memory usage optimization..." -ForegroundColor White

$output = cmd /c "fsutil behavior set memoryusage 2 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully set FSUtil memoryusage to 2." -ForegroundColor Green
} else {
    Write-Warning "Failed to set memoryusage: $output"
}

Write-Host "File system memory usage optimization complete." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
