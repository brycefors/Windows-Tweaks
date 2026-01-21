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

$taskName = "WingetAutoUpdateUser"
# Command to run winget upgrade twice with a delay
$wingetCommand = "winget upgrade --all --accept-source-agreements --accept-package-agreements; Start-Sleep -Seconds 15; winget upgrade --all --accept-source-agreements --accept-package-agreements"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script creates a Scheduled Task that runs as the current user"
Write-Host "at logon."
Write-Host ""
Write-Host "It executes 'winget upgrade --all' twice to ensure all packages"
Write-Host "are updated (handling dependencies or transient failures)."
Write-Host ""
Write-Host "Task Name: $taskName"
Write-Host "Trigger:   At Logon"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -Command `"$wingetCommand`""
$trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

try {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "Removed existing task: $taskName" -ForegroundColor Yellow
    }

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User $env:USERNAME -RunLevel Highest -ErrorAction Stop
    Write-Host "Successfully created Scheduled Task: $taskName" -ForegroundColor Green
    Write-Host "The task will run automatically the next time you log in." -ForegroundColor White -BackgroundColor DarkGreen
} catch {
    Write-Error "Failed to create Scheduled Task: $_"
    Write-Host "Ensure you have permissions to create Scheduled Tasks." -ForegroundColor Yellow
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
