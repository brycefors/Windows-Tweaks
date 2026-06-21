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
    [void][System.Diagnostics.Process]::Start($processInfo)
    exit
}

$taskName = "MonthlyDISMAndSFC"
$runDay = 1
$runTime = "03:00"
$taskDescription = "Runs monthly DISM and SFC integrity/repair scans as SYSTEM."
$maintenanceCommand = "dism /online /cleanup-image /restorehealth; sfc /scannow"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script creates a Scheduled Task that runs DISM and SFC"
Write-Host "automatically once per month to repair Windows image/system files."
Write-Host ""
Write-Host "Task Name: $taskName"
Write-Host "Description: $taskDescription"
Write-Host "Trigger:   Monthly (Day $runDay at $runTime)"
Write-Host "Account:   SYSTEM (highest privileges)"
Write-Host "Actions:"
Write-Host "  1. dism /online /cleanup-image /restorehealth"
Write-Host "  2. sfc /scannow"
Write-Host ""
Write-Host "NOTE: This can take a while and may use noticeable CPU/disk resources."
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
$taskArguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$maintenanceCommand`""

try {
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -ne $existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "Removed existing task: $taskName" -ForegroundColor Yellow
    }

    if ($runDay -lt 1 -or $runDay -gt 31) {
        throw "runDay must be between 1 and 31."
    }

    $runTimeDate = [DateTime]::ParseExact($runTime, 'HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
    $now = Get-Date
    $daysInMonth = [DateTime]::DaysInMonth($now.Year, $now.Month)
    $effectiveDay = [Math]::Min($runDay, $daysInMonth)
    $startBoundaryDate = Get-Date -Year $now.Year -Month $now.Month -Day $effectiveDay -Hour $runTimeDate.Hour -Minute $runTimeDate.Minute -Second 0
    if ($startBoundaryDate -le $now) {
        $nextMonth = $now.AddMonths(1)
        $daysInNextMonth = [DateTime]::DaysInMonth($nextMonth.Year, $nextMonth.Month)
        $effectiveDay = [Math]::Min($runDay, $daysInNextMonth)
        $startBoundaryDate = Get-Date -Year $nextMonth.Year -Month $nextMonth.Month -Day $effectiveDay -Hour $runTimeDate.Hour -Minute $runTimeDate.Minute -Second 0
    }
    $startBoundary = $startBoundaryDate.ToString('s')

    $scheduleService = New-Object -ComObject "Schedule.Service"
    $scheduleService.Connect()
    $rootFolder = $scheduleService.GetFolder("\")
    $taskDefinition = $scheduleService.NewTask(0)

    $taskDefinition.RegistrationInfo.Description = $taskDescription
    $taskDefinition.Settings.Enabled = $true
    $taskDefinition.Settings.StartWhenAvailable = $true
    $taskDefinition.Principal.UserId = "SYSTEM"
    $taskDefinition.Principal.LogonType = 5
    $taskDefinition.Principal.RunLevel = 1

    # Monthly trigger: day-of-month and all months.
    $monthlyTrigger = $taskDefinition.Triggers.Create(4)
    $monthlyTrigger.StartBoundary = $startBoundary
    $monthlyTrigger.DaysOfMonth = (1 -shl ($runDay - 1))
    $monthlyTrigger.MonthsOfYear = 4095
    $monthlyTrigger.Enabled = $true

    $taskAction = $taskDefinition.Actions.Create(0)
    $taskAction.Path = "powershell.exe"
    $taskAction.Arguments = $taskArguments

    # 6 = TASK_CREATE_OR_UPDATE, 5 = TASK_LOGON_SERVICE_ACCOUNT
    $null = $rootFolder.RegisterTaskDefinition($taskName, $taskDefinition, 6, "SYSTEM", $null, 5, $null)

    Write-Host "Successfully created Scheduled Task: $taskName" -ForegroundColor Green
    Write-Host "The task will run monthly and execute DISM then SFC." -ForegroundColor White -BackgroundColor DarkGreen
} catch {
    Write-Error "Failed to create Scheduled Task: $_"
    Write-Host "Ensure you have permissions to create Scheduled Tasks." -ForegroundColor Yellow
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
