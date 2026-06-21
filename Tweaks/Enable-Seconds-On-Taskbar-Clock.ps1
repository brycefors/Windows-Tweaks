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

$registrySubPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$name = "ShowSecondsInSystemClock"
$value = 1

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script enables seconds to be displayed in the system clock on the taskbar."
Write-Host ""
Write-Host "This tweak is applied to ALL user profiles on the system."
Write-Host ""
Write-Host "Target Registry Key: HKU:\<SID>\$registrySubPath"
Write-Host "Value to Set:        $name = $value"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
Write-Host "Applying taskbar clock tweak to all user profiles..." -ForegroundColor White

# Mount the HKU registry hive if not already mounted
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    Write-Host "Mounting HKU registry hive..." -ForegroundColor White
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

# Get all user SIDs from the registry, including Microsoft account / Entra-backed profiles.
$userSIDs = Get-ChildItem "HKU:\" | Where-Object { $_.PSChildName -match '^(S-1-5-21-|S-1-12-1-)' -and $_.PSChildName -notlike '*_Classes' } | Select-Object -ExpandProperty PSChildName

# Add the default user profile
$allProfiles = @('.DEFAULT') + $userSIDs

if ($allProfiles.Count -eq 0) {
    Write-Warning "No user profiles found in HKU:\"
} else {
    $successCount = 0
    foreach ($sid in $allProfiles) {
        $registryPath = "HKU:\$sid\$registrySubPath"
        
        try {
            if (-not (Test-Path $registryPath)) {
                New-Item -Path $registryPath -Force -ErrorAction Stop | Out-Null
            }
            
            Set-ItemProperty -Path $registryPath -Name $name -Value $value -Type DWord -ErrorAction Stop
            Write-Host "Successfully applied tweak to profile: $sid" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Warning "Failed to apply to profile $sid : $_"
        }
    }
    
    Write-Host ""
    Write-Host "Applied to $successCount user profile(s)." -ForegroundColor Green
}

Write-Host "You may need to restart Explorer or sign out for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")