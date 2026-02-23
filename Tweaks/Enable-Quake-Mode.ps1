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

$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$name = "WindowsTerminalQuake"
$value = "wt.exe -w _quake pwsh -window minimized"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script performs the following:"
Write-Host "1. Checks if PowerShell 7 is installed. If not, installs it via Winget."
Write-Host "2. Checks if Windows Terminal is installed. If not, installs it."
Write-Host "3. Configures Windows Terminal to start in 'Quake Mode' automatically"
Write-Host "   at user login."
Write-Host ""
Write-Host "Quake Mode allows you to toggle a terminal window from the top of"
Write-Host "the screen using a global hotkey (default: Win + ``)."
Write-Host ""
Write-Host "Registry Key: $registryPath"
Write-Host "Value:        $name = $value"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic

# 1. Install PowerShell 7
Write-Host "Checking for PowerShell 7..." -ForegroundColor White
if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
    Write-Host "PowerShell 7 is already installed." -ForegroundColor Green
} else {
    Write-Host "PowerShell 7 not found. Installing via Winget..." -ForegroundColor Yellow
    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Successfully installed PowerShell 7." -ForegroundColor Green
        } else {
            Write-Error "Winget installation failed with exit code: $($process.ExitCode)"
        }
    } catch {
        Write-Error "Failed to execute Winget: $_"
    }
}

# 2. Install Windows Terminal (Required for Quake Mode)
Write-Host "Checking for Windows Terminal..." -ForegroundColor White
if (Get-Command "wt" -ErrorAction SilentlyContinue) {
    Write-Host "Windows Terminal is already installed." -ForegroundColor Green
} else {
    Write-Host "Windows Terminal not found. Installing via Winget..." -ForegroundColor Yellow
    Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.WindowsTerminal --source winget --accept-package-agreements --accept-source-agreements" -Wait
}

# 3. Configure Startup
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

try {
    Set-ItemProperty -Path $registryPath -Name $name -Value $value -Type String -ErrorAction Stop
    Write-Host "Successfully added startup entry for Windows Terminal Quake Mode." -ForegroundColor Green
    Write-Host "The terminal will start automatically in Quake Mode next time you log in." -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "Note: The window will appear at the top of the screen. Press Win+`` to toggle." -ForegroundColor Gray
} catch {
    Write-Error "Failed to set registry value: $_"
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
