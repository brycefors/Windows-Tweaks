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
$encodedBytes = [System.Text.Encoding]::Unicode.GetBytes($maintenanceCommand)
$encodedCommand = [Convert]::ToBase64String($encodedBytes)
$taskRunCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"

try {
    $queryArgs = @('/Query', '/TN', $taskName)
    $queryOutput = & schtasks.exe @queryArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        $deleteArgs = @('/Delete', '/TN', $taskName, '/F')
        $deleteOutput = & schtasks.exe @deleteArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Removed existing task: $taskName" -ForegroundColor Yellow
        } else {
            throw "schtasks delete failed: $deleteOutput"
        }
    }

    $createArgs = @(
        '/Create', '/TN', $taskName,
        '/SC', 'MONTHLY',
        '/D', $runDay,
        '/ST', $runTime,
        '/RU', 'SYSTEM',
        '/RL', 'HIGHEST',
        '/F',
        '/TR', $taskRunCommand
    )
    $createOutput = & schtasks.exe @createArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        try {
            $scheduleService = New-Object -ComObject "Schedule.Service"
            $scheduleService.Connect()
            $rootFolder = $scheduleService.GetFolder("\")
            $registeredTask = $rootFolder.GetTask("\$taskName")
            $taskDefinition = $registeredTask.Definition
            $taskDefinition.RegistrationInfo.Description = $taskDescription

            # 6 = TASK_CREATE_OR_UPDATE, 5 = TASK_LOGON_SERVICE_ACCOUNT
            $null = $rootFolder.RegisterTaskDefinition($taskName, $taskDefinition, 6, "SYSTEM", $null, 5, $null)
        } catch {
            Write-Warning "Task created, but failed to set description: $_"
        }

        Write-Host "Successfully created Scheduled Task: $taskName" -ForegroundColor Green
        Write-Host "The task will run monthly and execute DISM then SFC." -ForegroundColor White -BackgroundColor DarkGreen
    } else {
        throw "schtasks failed: $createOutput"
    }
} catch {
    Write-Error "Failed to create Scheduled Task: $_"
    Write-Host "Ensure you have permissions to create Scheduled Tasks." -ForegroundColor Yellow
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
