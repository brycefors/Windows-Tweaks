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

$registrySubPath = "Control Panel\Desktop"
$name = "MenuShowDelay"
$value = "0"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script removes the menu open delay by setting MenuShowDelay to 0."
Write-Host ""
Write-Host "This tweak is applied to ALL user profiles and the default profile template."
Write-Host ""
Write-Host "Target Registry Key: HKU:\<SID>\$registrySubPath"
Write-Host "Value to Set:        $name = $value"
Write-Host "Type:                String"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
Write-Host "Applying menu delay tweak to all user profiles..." -ForegroundColor White

if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
	Write-Host "Mounting HKU registry hive..." -ForegroundColor White
	New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

function Set-MenuDelayValue {
	param(
		[Parameter(Mandatory = $true)]
		[string]$HiveRoot
	)

	$registryPath = "Registry::$HiveRoot\\$registrySubPath"
	if (-not (Test-Path $registryPath)) {
		New-Item -Path $registryPath -Force -ErrorAction Stop | Out-Null
	}

	Set-ItemProperty -Path $registryPath -Name $name -Value $value -Type String -ErrorAction Stop
}

$successCount = 0
$failedProfiles = @()

# Apply to .DEFAULT hive first.
try {
	Set-MenuDelayValue -HiveRoot "HKEY_USERS\.DEFAULT"
	Write-Host "Successfully applied tweak to profile: .DEFAULT" -ForegroundColor Green
	$successCount++
} catch {
	Write-Warning "Failed to apply to profile .DEFAULT : $_"
	$failedProfiles += ".DEFAULT"
}

# Discover profile SIDs from ProfileList so unloaded profiles are included.
$profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profileEntries = Get-ChildItem $profileListPath -ErrorAction SilentlyContinue | Where-Object {
	$_.PSChildName -match '^(S-1-5-21-|S-1-12-1-)'
}

foreach ($entry in $profileEntries) {
	$sid = $entry.PSChildName
	$loadedHivePath = "HKU:\$sid"

	if (Test-Path $loadedHivePath) {
		try {
			Set-MenuDelayValue -HiveRoot "HKEY_USERS\$sid"
			Write-Host "Successfully applied tweak to profile: $sid" -ForegroundColor Green
			$successCount++
		} catch {
			Write-Warning "Failed to apply to profile $sid : $_"
			$failedProfiles += $sid
		}
		continue
	}

	$profileImagePath = (Get-ItemProperty -Path $entry.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
	if ([string]::IsNullOrWhiteSpace($profileImagePath)) {
		Write-Warning "Skipped profile $sid (missing ProfileImagePath)."
		$failedProfiles += $sid
		continue
	}

	$expandedProfilePath = [Environment]::ExpandEnvironmentVariables($profileImagePath)
	$ntUserDatPath = Join-Path $expandedProfilePath "NTUSER.DAT"
	if (-not (Test-Path $ntUserDatPath)) {
		Write-Warning "Skipped profile $sid (NTUSER.DAT not found at $ntUserDatPath)."
		$failedProfiles += $sid
		continue
	}

	$tempHiveName = "TempProfile_$($sid -replace '-', '_')"
	$tempHiveRoot = "HKEY_USERS\$tempHiveName"

	$null = & reg.exe load "HKU\$tempHiveName" "$ntUserDatPath" 2>$null
	if ($LASTEXITCODE -ne 0) {
		Write-Warning "Failed to load profile hive for $sid from $ntUserDatPath."
		$failedProfiles += $sid
		continue
	}

	try {
		Set-MenuDelayValue -HiveRoot $tempHiveRoot
		Write-Host "Successfully applied tweak to profile: $sid" -ForegroundColor Green
		$successCount++
	} catch {
		Write-Warning "Failed to apply to profile $sid : $_"
		$failedProfiles += $sid
	} finally {
		$null = & reg.exe unload "HKU\$tempHiveName" 2>$null
	}
}

# Apply to C:\Users\Default so newly created local profiles inherit the value.
$defaultNtUserDat = "$env:SystemDrive\Users\Default\NTUSER.DAT"
if (Test-Path $defaultNtUserDat) {
	$defaultTempHive = "TempProfile_DefaultTemplate"
	$null = & reg.exe load "HKU\$defaultTempHive" "$defaultNtUserDat" 2>$null

	if ($LASTEXITCODE -eq 0) {
		try {
			Set-MenuDelayValue -HiveRoot "HKEY_USERS\$defaultTempHive"
			Write-Host "Successfully applied tweak to default profile template." -ForegroundColor Green
			$successCount++
		} catch {
			Write-Warning "Failed to apply to default profile template : $_"
			$failedProfiles += "DefaultTemplate"
		} finally {
			$null = & reg.exe unload "HKU\$defaultTempHive" 2>$null
		}
	} else {
		Write-Warning "Failed to load default profile template hive from $defaultNtUserDat."
		$failedProfiles += "DefaultTemplate"
	}
} else {
	Write-Warning "Default profile template NTUSER.DAT not found at $defaultNtUserDat."
}

Write-Host ""
Write-Host "Applied to $successCount profile hive(s)." -ForegroundColor Green
if ($failedProfiles.Count -gt 0) {
	$uniqueFailures = $failedProfiles | Sort-Object -Unique
	Write-Warning "Some profiles could not be updated: $($uniqueFailures -join ', ')"
}

Write-Host "Sign out and back in (or restart) to ensure Explorer picks up the change." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
