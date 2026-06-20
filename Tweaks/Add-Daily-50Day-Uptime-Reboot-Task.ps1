# Run this script in PowerShell
# Auto-elevates to Administrator if run as a standard user.

param(
    [int]$ThresholdDays = 50,
    [int]$RebootDelaySeconds = 300
)

# --- AUTO-ELEVATION BLOCK ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Elevating..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
    $processInfo.Verb = "RunAs"
    [void][System.Diagnostics.Process]::Start($processInfo)
    exit
}

$taskName = "Daily50DayUptimeReboot"
$runTime = "02:00"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script creates a Scheduled Task that runs once per day"
Write-Host "as SYSTEM and checks OS uptime."
Write-Host ""
Write-Host "If uptime is $ThresholdDays days or more, it schedules a reboot"
Write-Host "with a $RebootDelaySeconds-second delay."
Write-Host ""
Write-Host "Why this matters: Windows Patch Tuesday generally expects monthly"
Write-Host "reboots to fully apply updates and maintain stability."
Write-Host ""
Write-Host "Task Name: $taskName"
Write-Host "Trigger:   Daily at $runTime"
Write-Host "User:      SYSTEM"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
$taskScript = @"
`$uptimeDays = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalDays
if (`$uptimeDays -ge $ThresholdDays) {
    shutdown.exe /r /t $RebootDelaySeconds /c "System uptime reached $ThresholdDays days. Rebooting for monthly patch hygiene and stability."
}
"@
$encodedTaskScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($taskScript))
$taskArguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encodedTaskScript"

try {
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -ne $existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "Removed existing task: $taskName" -ForegroundColor Yellow
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $taskArguments
    $trigger = New-ScheduledTaskTrigger -Daily -At $runTime
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -RunLevel Highest -Force -ErrorAction Stop | Out-Null
    Write-Host "Successfully created Scheduled Task: $taskName" -ForegroundColor Green
    Write-Host "The task will reboot the system when uptime reaches $ThresholdDays+ days." -ForegroundColor White -BackgroundColor DarkGreen
} catch {
    Write-Error "Failed to create Scheduled Task: $_"
    Write-Host "Ensure you have permissions to create Scheduled Tasks." -ForegroundColor Yellow
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
