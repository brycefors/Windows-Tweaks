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

# Only proceed on Dell systems.
$system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
$manufacturer = $system.Manufacturer
if ($manufacturer -notmatch "Dell") {
	Write-Warning "This does not appear to be a Dell system (Manufacturer: '$manufacturer'). No changes made."
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script disables common non-essential Dell background services"
Write-Host "that are often bundled with SupportAssist / telemetry components."
Write-Host ""
Write-Host "Actions:"
Write-Host "1. Stops matching Dell services if currently running."
Write-Host "2. Sets their startup type to Disabled."
Write-Host "3. Optionally removes Dell pinned taskbar icons for all users."
Write-Host ""
Write-Host "Targeted services can include:"
Write-Host "  - Dell SupportAssist"
Write-Host "  - Dell SupportAssist Remediation"
Write-Host "  - Dell Trusted Device"
Write-Host "  - Dell Optimizer"
Write-Host "  - Dell Data Vault Collector / Processor / API"
# Write-Host "  - Dell Client Management Service"
# Write-Host "  - Dell TechHub"
Write-Host "  - Dell Digital Delivery"
Write-Host ""
Write-Host "NOTE: If you rely on Dell SupportAssist automation, this may remove" -ForegroundColor Yellow
Write-Host "its automatic diagnostics/update behavior." -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Resolve services by both service name and display name to support model/software differences.
$targetNames = @(
	"SupportAssistAgent",
	"SupportAssistRemediation",
	"DellTrustedDevice",
	"DellTrustedDeviceAgent",
	"DellOptimizer",
	"DellOptimizerService",
#	"DellClientManagementService", # May break Dell peripherals management if disabled.
#	"Dell.TechHub", # May break Dell peripherals management if disabled.
	"DDVCollectorSvcApi",
	"DDVDataCollector",
	"DDVRulesProcessor",
	"DellDigitalDelivery"
)

$targetDisplayNames = @(
	"Dell SupportAssist",
	"Dell SupportAssist Remediation",
	"Dell Trusted Device",
	"Dell Trusted Device Agent",
	"Dell Optimizer",
	"Dell Optimizer Service",
	"Dell Data Vault Collector",
	"Dell Data Vault Processor",
	"Dell Data Vault Service API",
#	"Dell Client Management Service", # May break Dell peripherals management if disabled.
#	"Dell TechHub", # May break Dell peripherals management if disabled.
	"Dell Digital Delivery Services"
)

$allServices = Get-Service -ErrorAction SilentlyContinue
$matchedServices = $allServices | Where-Object {
	($targetNames -contains $_.Name) -or ($targetDisplayNames -contains $_.DisplayName)
}

if (-not $matchedServices) {
	Write-Host "No targeted Dell annoyance services were found on this system." -ForegroundColor Yellow
} else {
	$disabledCount = 0
	foreach ($svc in $matchedServices) {
		try {
			if ($svc.Status -ne 'Stopped') {
				Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
			}

			Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
			Write-Host "Disabled: $($svc.DisplayName) [$($svc.Name)]" -ForegroundColor Green
			$disabledCount++
		} catch {
			Write-Warning "Failed to disable service '$($svc.Name)': $_"
		}
	}

	Write-Host ""
	Write-Host "Successfully disabled $disabledCount service(s)." -ForegroundColor Green
}

# Optional: remove Dell-related pinned taskbar shortcuts for all local users.
Write-Host ""
$removeTaskbarIconsResponse = Read-Host "Remove Dell icons from taskbar for all users on this machine? (Y/N)"
if ($removeTaskbarIconsResponse -match '^[Yy]') {
	$shell = New-Object -ComObject WScript.Shell
	$taskbarRemovedCount = 0
	$profilesTouched = 0

	$profileListRoot = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
	$profilePaths = @()
	if (Test-Path $profileListRoot) {
		$profilePaths = Get-ChildItem -Path $profileListRoot -ErrorAction SilentlyContinue |
			ForEach-Object {
				(Get-ItemProperty -Path $_.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
			} |
			Where-Object { $_ } |
			ForEach-Object { [Environment]::ExpandEnvironmentVariables($_) } |
			Where-Object { (Test-Path $_) -and ($_ -notmatch '(?i)\\Windows\\System32\\config\\systemprofile$') } |
			Sort-Object -Unique
	}

	# Include Default profile so future users don't inherit Dell taskbar pins.
	$defaultProfilePath = Join-Path $env:SystemDrive "Users\Default"
	if (Test-Path $defaultProfilePath) {
		$profilePaths += $defaultProfilePath
	}
	$profilePaths = $profilePaths | Sort-Object -Unique

	if (-not $profilePaths) {
		Write-Host "No eligible user profiles found." -ForegroundColor Yellow
	} else {
		foreach ($profilePath in $profilePaths) {
			$taskbarPinnedPath = Join-Path $profilePath "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
			if (-not (Test-Path $taskbarPinnedPath)) {
				continue
			}

			$profilesTouched++
			$taskbarLinks = Get-ChildItem -Path $taskbarPinnedPath -Filter "*.lnk" -File -ErrorAction SilentlyContinue

			foreach ($link in $taskbarLinks) {
				$removeLink = $false

				if ($link.Name -match '(?i)dell|supportassist|optimizer|trusted') {
					$removeLink = $true
				} else {
					try {
						$shortcut = $shell.CreateShortcut($link.FullName)
						if ($shortcut.TargetPath -and $shortcut.TargetPath -match '(?i)dell|supportassist|optimizer|trusted') {
							$removeLink = $true
						}
					} catch {
						Write-Warning "Could not inspect taskbar shortcut '$($link.FullName)': $_"
					}
				}

				if ($removeLink) {
					try {
						Remove-Item -Path $link.FullName -Force -ErrorAction Stop
						Write-Host "Removed taskbar shortcut: $($link.FullName)" -ForegroundColor Green
						$taskbarRemovedCount++
					} catch {
						Write-Warning "Failed to remove taskbar shortcut '$($link.FullName)': $_"
					}
				}
			}
		}

		Write-Host "Processed $profilesTouched profile(s)." -ForegroundColor Green
		Write-Host "Removed $taskbarRemovedCount Dell-related taskbar shortcut(s)." -ForegroundColor Green
		Write-Host "If taskbar icons do not refresh immediately, restart Explorer or sign out/in." -ForegroundColor Yellow
	}
} else {
	Write-Host "Skipped taskbar icon removal." -ForegroundColor Yellow
}

Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
