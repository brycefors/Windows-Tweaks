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
	[System.Diagnostics.Process]::Start($processInfo) | Out-Null
	exit
}

# Set to $true to automatically confirm all optional actions without prompting.
$AutoConfirm = $false

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
Write-Host "3. Disables Dell SupportAssistAgent AutoUpdate scheduled task."
Write-Host "4. Optionally removes Dell pinned taskbar icons for all users."
Write-Host "5. Optionally uninstalls Dell SupportAssist components (registry-based and AppX)."
Write-Host "6. Optionally uninstalls Cirrus Logic audio drivers and software."
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
Write-Host "Some services may not stop completely until after a restart." -ForegroundColor Yellow
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
#	"DellClientManagementService", # Needed for Dell peripheral and Dell Command suite.
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
#	"Dell Client Management Service", # Needed for Dell peripheral and Dell Command suite.
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
	$alreadyDisabledCount = 0
	foreach ($svc in $matchedServices) {
		try {
			$svcEscapedName = $svc.Name.Replace("'", "''")
			$svcDetails = Get-CimInstance -ClassName Win32_Service -Filter "Name='$svcEscapedName'" -ErrorAction SilentlyContinue
			if ($svcDetails -and $svcDetails.StartMode -eq 'Disabled') {
				Write-Host "Already disabled: $($svc.DisplayName) [$($svc.Name)]" -ForegroundColor Yellow
				$alreadyDisabledCount++
				continue
			}

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
	Write-Host "Already disabled $alreadyDisabledCount service(s)." -ForegroundColor Yellow
}

# Disable Dell SupportAssistAgent AutoUpdate scheduled task if present.
$targetTaskName = "Dell SupportAssistAgent AutoUpdate"
try {
	$matchingTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq $targetTaskName }
	if (-not $matchingTasks) {
	#	Write-Host "Scheduled task not found: $targetTaskName" -ForegroundColor Yellow
	} else {
		$taskDisabledCount = 0
		$taskAlreadyDisabledCount = 0

		foreach ($task in $matchingTasks) {
			if ($task.State -eq 'Disabled') {
				Write-Host "Task already disabled: $($task.TaskPath)$($task.TaskName)" -ForegroundColor Yellow
				$taskAlreadyDisabledCount++
				continue
			}

			Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
			Write-Host "Disabled scheduled task: $($task.TaskPath)$($task.TaskName)" -ForegroundColor Green
			$taskDisabledCount++
		}

		Write-Host "Disabled $taskDisabledCount scheduled task(s): $targetTaskName" -ForegroundColor Green
		Write-Host "Already disabled $taskAlreadyDisabledCount scheduled task(s): $targetTaskName" -ForegroundColor Yellow
	}
} catch {
	Write-Warning "Failed while processing scheduled task '$targetTaskName': $_"
}

# --- SCAN FOR OPTIONAL ITEMS ---
Write-Host ""
Write-Host "Scanning for optional cleanup items..." -ForegroundColor Cyan

# Scan for Dell taskbar icons
$dellTaskbarIconsFound = $false
$taskbarIconPaths = @()
$profileListRoot = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
if (Test-Path $profileListRoot) {
	$profilePaths = Get-ChildItem -Path $profileListRoot -ErrorAction SilentlyContinue |
		ForEach-Object {
			(Get-ItemProperty -Path $_.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
		} |
		Where-Object { $_ } |
		ForEach-Object { [Environment]::ExpandEnvironmentVariables($_) } |
		Where-Object { (Test-Path $_) -and ($_ -notmatch '(?i)\\Windows\\System32\\config\\systemprofile$') } |
		Sort-Object -Unique

	$defaultProfilePath = Join-Path $env:SystemDrive "Users\Default"
	if (Test-Path $defaultProfilePath) {
		$profilePaths += $defaultProfilePath
	}
	$profilePaths = $profilePaths | Sort-Object -Unique

	foreach ($profilePath in $profilePaths) {
		$taskbarPinnedPath = Join-Path $profilePath "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
		if (Test-Path $taskbarPinnedPath) {
			$taskbarLinks = Get-ChildItem -Path $taskbarPinnedPath -Filter "*.lnk" -File -ErrorAction SilentlyContinue
			foreach ($link in $taskbarLinks) {
				if ($link.Name -match '(?i)dell|supportassist|optimizer|trusted') {
					$dellTaskbarIconsFound = $true
					$taskbarIconPaths += $link.FullName
				}
			}
		}
	}
}

# Scan for Dell SupportAssist packages
$supportAssistPackagesFound = @()
$uninstallRegistryPaths = @(
	"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
	"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$targetAppNames = @(
	"Dell SupportAssist",
	"Dell SupportAssist Remediation",
	"Dell SupportAssist OS Recovery Plugin for Dell Update"
)
foreach ($path in $uninstallRegistryPaths) {
	$appEntries = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
		Where-Object {
			$_.DisplayName -and ($targetAppNames -contains $_.DisplayName)
		} |
		Select-Object DisplayName, QuietUninstallString, UninstallString
	$supportAssistPackagesFound += $appEntries
}
$supportAssistPackagesFound = $supportAssistPackagesFound | Sort-Object DisplayName -Unique

# Scan for Cirrus Logic packages
$cirrusPackagesFound = @()
foreach ($regPath in $uninstallRegistryPaths) {
	if (Test-Path $regPath) {
		$items = Get-ChildItem $regPath -ErrorAction SilentlyContinue
		foreach ($item in $items) {
			$displayName = (Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue).DisplayName
			if (($displayName -match "Cirrus" -or $displayName -match "CirrusLogic") -and $displayName -notmatch "(?i)setup") {
				$cirrusPackagesFound += @{
					Path = $item.PSPath
					Name = $displayName
					UninstallString = (Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue).UninstallString
				}
			}
		}
	}
}

$anyOptionalFound = $dellTaskbarIconsFound -or ($supportAssistPackagesFound.Count -gt 0) -or ($cirrusPackagesFound.Count -gt 0)

Write-Host "Scan complete." -ForegroundColor Green
Write-Host ""

if (-not $anyOptionalFound) {
	Write-Host "No optional cleanup components found." -ForegroundColor Yellow
} else {
	if (-not $AutoConfirm) {
		$autoConfirmResponse = Read-Host "Auto-confirm all optional cleanup actions? (Y/N)"
		if ($autoConfirmResponse -match '^[Yy]') {
			$AutoConfirm = $true
		}
	}
}
Write-Host ""

# Optional: remove Dell-related pinned taskbar shortcuts for all local users.
if ($dellTaskbarIconsFound) {
	if ($AutoConfirm -or (Read-Host "Found Dell taskbar icons. Remove them for all users on this machine? (Y/N)") -match '^[Yy]') {
		$taskbarRemovedCount = 0

		foreach ($link in $taskbarIconPaths) {
			try {
				Remove-Item -Path $link -Force -ErrorAction Stop
				Write-Host "Removed taskbar shortcut: $link" -ForegroundColor Green
				$taskbarRemovedCount++
			} catch {
				Write-Warning "Failed to remove taskbar shortcut '$link': $_"
			}
		}

		Write-Host "Removed $taskbarRemovedCount Dell-related taskbar shortcut(s)." -ForegroundColor Green
		Write-Host "If taskbar icons do not refresh immediately, restart Explorer or sign out/in." -ForegroundColor Yellow
	}
}

# Optional: uninstall Dell SupportAssist components (registry-based and AppX).
if ($supportAssistPackagesFound.Count -gt 0) {
	if ($AutoConfirm -or (Read-Host "Found Dell SupportAssist packages. Uninstall them now? (Y/N)") -match '^[Yy]') {
		$uninstallSuccessCount = 0
		$uninstallFailedCount = 0

		foreach ($app in $supportAssistPackagesFound) {
			$commandToRun = $null
			if ($app.QuietUninstallString) {
				$commandToRun = $app.QuietUninstallString
			} elseif ($app.UninstallString) {
				$commandToRun = $app.UninstallString
			}

			if (-not $commandToRun) {
				Write-Warning "No uninstall command found for '$($app.DisplayName)'."
				$uninstallFailedCount++
				continue
			}

			# Make MSI uninstall commands non-interactive when possible.
			if ($commandToRun -match '(?i)msiexec(\.exe)?') {
				$commandToRun = $commandToRun -replace '(?i)\s/I\s', ' /X '
				if ($commandToRun -notmatch '(?i)\s/q') {
					$commandToRun += ' /qn'
				}
				if ($commandToRun -notmatch '(?i)norestart') {
					$commandToRun += ' /norestart'
				}
			}

			try {
				Write-Host "Uninstalling: $($app.DisplayName)" -ForegroundColor White
				$proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $commandToRun -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
				if ($proc.ExitCode -eq 0) {
					Write-Host "Uninstalled: $($app.DisplayName)" -ForegroundColor Green
					$uninstallSuccessCount++
				} else {
					Write-Warning "Uninstall returned exit code $($proc.ExitCode) for '$($app.DisplayName)'."
					$uninstallFailedCount++
				}
			} catch {
				Write-Warning "Failed to uninstall '$($app.DisplayName)': $_"
				$uninstallFailedCount++
			}
		}

		Write-Host "Uninstalled $uninstallSuccessCount application(s)." -ForegroundColor Green
		if ($uninstallFailedCount -gt 0) {
			Write-Host "Failed to uninstall $uninstallFailedCount application(s)." -ForegroundColor Yellow
		}

		# Remove Dell SupportAssist AppX packages (store/modern app installs).
		$targetAppxNames = @(
			"*DellSupportAssist*"
			"Dell.SupportAssist*"
			"DellInc.SupportAssist*"
		)

		$appxRemovedCount = 0
		$appxNotFoundCount = 0

		foreach ($appxName in $targetAppxNames) {
			$packages = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
			$provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
				Where-Object { $_.DisplayName -like $appxName }

			if (-not $packages -and -not $provisionedPackages) {
			#	Write-Host "AppX package not found: $appxName" -ForegroundColor Yellow
				$appxNotFoundCount++
				continue
			}

			foreach ($pkg in $packages) {
				try {
					Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
					Write-Host "Removed AppX package: $($pkg.Name) ($($pkg.PackageUserInformation.UserSecurityId -join ', '))" -ForegroundColor Green
					$appxRemovedCount++
				} catch {
					Write-Warning "Failed to remove AppX package '$($pkg.PackageFullName)': $_"
				}
			}

			foreach ($provPkg in $provisionedPackages) {
				try {
					Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction Stop | Out-Null
					Write-Host "Removed provisioned AppX package: $($provPkg.DisplayName)" -ForegroundColor Green
					$appxRemovedCount++
				} catch {
					Write-Warning "Failed to remove provisioned AppX package '$($provPkg.PackageName)': $_"
				}
			}
		}

		Write-Host "Removed $appxRemovedCount AppX package(s)." -ForegroundColor Green

		# Remove SupportAssist-related directories.
		$dirsToRemove = @(
			"$env:ProgramFiles\Dell\SupportAssist",
			"${env:ProgramFiles(x86)}\Dell\SupportAssist",
			"$env:ProgramData\Dell\SupportAssist",
			"$env:ProgramData\Dell\SARemediation",
			"$env:AppData\Dell\SupportAssist",
			"$env:LocalAppData\Dell\SupportAssist"
		)

		$dirRemovedCount = 0
		foreach ($dir in $dirsToRemove) {
			if (Test-Path $dir) {
				try {
					Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
					Write-Host "Removed directory: $dir" -ForegroundColor Green
					$dirRemovedCount++
				} catch {
					Write-Warning "Failed to remove directory '$dir': $_"
				}
			}
		}

		if ($dirRemovedCount -gt 0) {
			Write-Host "Removed $dirRemovedCount SupportAssist directory(ies)." -ForegroundColor Green
		}
	}
}

# Optional: uninstall Cirrus Logic audio drivers. Adds unncessary latency.
if ($cirrusPackagesFound.Count -gt 0) {
	if ($AutoConfirm -or (Read-Host "Found Cirrus Logic packages. Uninstall them now? (Y/N)") -match '^[Yy]') {
		$cirrusUninstalled = $false
		
		Write-Host ""
		Write-Host "Uninstalling Cirrus Logic audio drivers..." -ForegroundColor Cyan
		Write-Host ""

		# Uninstall Cirrus Logic software packages
		Write-Host "[1/3] Uninstalling Cirrus Logic software packages..." -ForegroundColor Cyan
		Write-Host "Found Cirrus Logic packages:" -ForegroundColor Green
		foreach ($pkg in $cirrusPackagesFound) {
			Write-Host "  - $($pkg.Name)" -ForegroundColor Yellow
			if ($pkg.UninstallString) {
				Write-Host "    Attempting to uninstall..." -ForegroundColor Yellow
				try {
					$cirrusCmd = $pkg.UninstallString
					if ($cirrusCmd -match '(?i)msiexec(\.exe)?') {
						$cirrusCmd = $cirrusCmd -replace '(?i)\s/I\s', ' /X '
						if ($cirrusCmd -notmatch '(?i)\s/q') { $cirrusCmd += ' /qn' }
						if ($cirrusCmd -notmatch '(?i)norestart') { $cirrusCmd += ' /norestart' }
						& cmd /c $cirrusCmd 2>$null
					} else {
						& cmd /c $cirrusCmd /S /norestart 2>$null
					}
					Write-Host "    Uninstalled successfully." -ForegroundColor Green
					$cirrusUninstalled = $true
				} catch {
					Write-Warning "    Failed to uninstall package: $_"
				}
			}
		}

		# Clean up Cirrus Logic registry entries
		Write-Host ""
		Write-Host "[2/3] Cleaning up Cirrus Logic registry entries..." -ForegroundColor Cyan
		$regSearchPaths = @(
			"HKLM:\Software\Cirrus",
			"HKCU:\Software\Cirrus"
		)

		foreach ($regPath in $regSearchPaths) {
			if (Test-Path $regPath) {
				Write-Host "Removing registry key: $regPath" -ForegroundColor Yellow
				try {
					Remove-Item $regPath -Recurse -Force -ErrorAction Stop
					Write-Host "Registry key removed." -ForegroundColor Green
					$cirrusUninstalled = $true
				} catch {
					Write-Warning "Failed to remove registry key '$regPath': $_"
				}
			}
		}

		# Remove Cirrus-related program directories
		Write-Host ""
		Write-Host "[3/3] Removing Cirrus Logic application directories..." -ForegroundColor Cyan
		$cirrusDirs = @(
			"$env:ProgramFiles\Cirrus",
			"${env:ProgramFiles(x86)}\Cirrus",
			"$env:ProgramData\Cirrus",
			"$env:AppData\Cirrus",
			"$env:LocalAppData\Cirrus"
		)

		$cirrusDirsRemoved = $false
		foreach ($dir in $cirrusDirs) {
			if (Test-Path $dir) {
				try {
					Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
					Write-Host "Removed directory: $dir" -ForegroundColor Green
					$cirrusUninstalled = $true
					$cirrusDirsRemoved = $true
				} catch {
					Write-Warning "Failed to remove directory '$dir': $_"
				}
			}
		}

		if (-not $cirrusDirsRemoved) {
			Write-Host "No Cirrus Logic directories found to remove." -ForegroundColor Yellow
		}

		Write-Host ""
		if ($cirrusUninstalled) {
			Write-Host "Cirrus Logic audio drivers have been uninstalled." -ForegroundColor Green
		} else {
			Write-Host "No Cirrus Logic drivers or packages were found to uninstall." -ForegroundColor Yellow
		}
	}
}

Write-Host ""
Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "A restart may be required for all targeted services to stop completely." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
