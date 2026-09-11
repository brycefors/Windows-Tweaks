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

# I am tired of seeing malware utilize notifications in browsers, so every browser gets them blocked.

# Machine-wide browser policies. Value 2 = "Block" for Chromium notification settings.
$policies = @(
    @{ Browser = "Google Chrome";  Path = "HKLM:\SOFTWARE\Policies\Google\Chrome";                              Name = "DefaultNotificationsSetting"; Value = 2 },
    @{ Browser = "Microsoft Edge"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge";                             Name = "DefaultNotificationsSetting"; Value = 2 },
    @{ Browser = "Brave";          Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";                        Name = "DefaultNotificationsSetting"; Value = 2 },
    @{ Browser = "Vivaldi";        Path = "HKLM:\SOFTWARE\Policies\Vivaldi";                                    Name = "DefaultNotificationsSetting"; Value = 2 },
    @{ Browser = "Opera";          Path = "HKLM:\SOFTWARE\Policies\Opera Software\Opera";                       Name = "DefaultNotificationsSetting"; Value = 2 },
    @{ Browser = "Chromium";       Path = "HKLM:\SOFTWARE\Policies\Chromium";                                   Name = "DefaultNotificationsSetting"; Value = 2 },
    @{ Browser = "Firefox";        Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Permissions\Notifications";  Name = "BlockNewRequests";            Value = 1 },
    @{ Browser = "Firefox";        Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Permissions\Notifications";  Name = "Locked";                      Value = 1 }
)

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script blocks website push notifications in all major"
Write-Host "browsers by writing machine-wide enterprise policies."
Write-Host ""
Write-Host "Covered browsers:"
Write-Host "  Chrome, Edge, Brave, Vivaldi, Opera, Chromium, Firefox"
Write-Host ""
Write-Host "Chromium browsers get DefaultNotificationsSetting = 2 (Block)."
Write-Host "Firefox gets Permissions\Notifications BlockNewRequests = 1"
Write-Host "and Locked = 1 so the setting cannot be changed in the UI."
Write-Host ""
Write-Host "The keys are written whether or not a browser is installed, so"
Write-Host "any of these browsers installed later is covered on first launch."
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic - apply the policies now
foreach ($policy in $policies) {
    try {
        if (-not (Test-Path $policy.Path)) {
            New-Item -Path $policy.Path -Force | Out-Null
            Write-Host "Created registry path: $($policy.Path)" -ForegroundColor Green
        }

        Set-ItemProperty -Path $policy.Path -Name $policy.Name -Value $policy.Value -Type DWord -Force -ErrorAction Stop
        Write-Host "$($policy.Browser): set '$($policy.Name)' to $($policy.Value)." -ForegroundColor Green
    } catch {
        Write-Error "Failed to set '$($policy.Name)' for $($policy.Browser): $_"
    }
}

Write-Host ""
Write-Host "Restart your browsers for the policies to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "A system restart is recommended." -ForegroundColor Yellow
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
