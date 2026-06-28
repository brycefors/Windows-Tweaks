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

$preferencesPath = "C:\ProgramData\Windows Master Store\Common\Preferences.json"
$pcManagerPackageId = "9PM860492SZD"
$pcManagerSource = "msstore"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script performs the following:"
Write-Host "1. Verifies whether Windows PC Manager is already installed."
Write-Host "2. Installs Windows PC Manager via Winget only if missing."
Write-Host "3. Updates PC Manager preferences to enable three settings:"
Write-Host "   - AutoUpdate = true"
Write-Host "   - SelfStart = true"
Write-Host "   - IsAppUsageEnabled = true"
Write-Host ""
Write-Host "Target file: $preferencesPath"
Write-Host "A timestamped backup is created before writing changes."
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
function Test-PCManagerInstalled {
    try {
        $startApp = Get-StartApps -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "PC Manager|Microsoft PC Manager|Windows PC Manager"
        } | Select-Object -First 1
        if ($null -ne $startApp) {
            return $true
        }
    } catch {
    }

    try {
        $appxPkg = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "PCManager|MicrosoftPCManager" -or $_.PackageFamilyName -match "PCManager"
        } | Select-Object -First 1
        if ($null -ne $appxPkg) {
            return $true
        }
    } catch {
    }

    return $false
}

if (Test-PCManagerInstalled) {
    Write-Host "Windows PC Manager is already installed. Skipping install step." -ForegroundColor Green
} else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "Windows PC Manager is not installed and Winget is unavailable. Install App Installer / Winget and retry."
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    Write-Host "Windows PC Manager not found. Installing via Winget..." -ForegroundColor White
    try {
        $installArgs = @(
            "install",
            "--id", $pcManagerPackageId,
            "--source", $pcManagerSource,
            "--exact",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--silent"
        )

        & winget @installArgs
        $installExitCode = $LASTEXITCODE
        if ($installExitCode -ne 0) {
            throw "Winget install failed for $pcManagerPackageId. Exit code: $installExitCode"
        }

        Write-Host "Windows PC Manager install step completed." -ForegroundColor Green
    } catch {
        Write-Error "Failed to install Windows PC Manager: $_"
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

$preferencesDirectory = Split-Path -Path $preferencesPath -Parent
if (-not (Test-Path $preferencesDirectory)) {
    New-Item -Path $preferencesDirectory -ItemType Directory -Force | Out-Null
}

$preferencesObject = $null
if (Test-Path $preferencesPath) {
    try {
        $backupPath = "$preferencesPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $preferencesPath -Destination $backupPath -Force
        Write-Host "Created backup: $backupPath" -ForegroundColor DarkGray

        $rawJson = Get-Content -Path $preferencesPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($rawJson)) {
            $preferencesObject = [PSCustomObject]@{}
        } else {
            $preferencesObject = $rawJson | ConvertFrom-Json -ErrorAction Stop
        }
    } catch {
        Write-Warning "Existing preferences file could not be parsed. A new preferences object will be written."
        $preferencesObject = [PSCustomObject]@{}
    }
} else {
    $preferencesObject = [PSCustomObject]@{}
}

if ($null -eq $preferencesObject) {
    $preferencesObject = [PSCustomObject]@{}
}

# These values must be written under the Settings object for PC Manager to honor them.
if (-not ($preferencesObject.PSObject.Properties.Name -contains "Settings") -or $null -eq $preferencesObject.Settings) {
    $preferencesObject | Add-Member -NotePropertyName "Settings" -NotePropertyValue ([PSCustomObject]@{}) -Force
}

if (-not ($preferencesObject.Settings -is [PSCustomObject])) {
    $preferencesObject.Settings = [PSCustomObject]@{}
}

$preferencesObject.Settings | Add-Member -NotePropertyName "AutoUpdate" -NotePropertyValue $true -Force
$preferencesObject.Settings | Add-Member -NotePropertyName "SelfStart" -NotePropertyValue $true -Force
$preferencesObject.Settings | Add-Member -NotePropertyName "IsAppUsageEnabled" -NotePropertyValue $true -Force

try {
    $jsonOut = $preferencesObject | ConvertTo-Json -Depth 20
    Set-Content -Path $preferencesPath -Value $jsonOut -Encoding UTF8 -Force
    Write-Host "Updated preferences successfully:" -ForegroundColor Green
    Write-Host "  AutoUpdate = true" -ForegroundColor Green
    Write-Host "  SelfStart = true" -ForegroundColor Green
    Write-Host "  IsAppUsageEnabled = true" -ForegroundColor Green
    Write-Host "Changes written to: $preferencesPath" -ForegroundColor White -BackgroundColor DarkGreen

    # Start PC Manager so the updated preferences can be picked up immediately.
    $startedPcManager = $false

    try {
        $pcManagerApp = Get-StartApps -ErrorAction Stop | Where-Object {
            $_.Name -match "PC Manager|Microsoft PC Manager|Windows PC Manager"
        } | Select-Object -First 1

        if ($null -ne $pcManagerApp -and -not [string]::IsNullOrWhiteSpace($pcManagerApp.AppID)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList "shell:AppsFolder\$($pcManagerApp.AppID)" -ErrorAction Stop
            $startedPcManager = $true
        }
    } catch {
        # Fall back to URI protocol if StartApps lookup is unavailable.
    }

    if (-not $startedPcManager) {
        try {
            Start-Process -FilePath "ms-pc-manager:" -ErrorAction Stop
            $startedPcManager = $true
        } catch {
            Write-Warning "Preferences were updated, but PC Manager could not be launched automatically."
        }
    }

    if ($startedPcManager) {
        Write-Host "PC Manager launched." -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to write preferences file: $_"
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")