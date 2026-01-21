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

$gamingRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script applies Network and Gaming latency optimizations:"
Write-Host "1. Disables Nagle's Algorithm (TCPNoDelay) on active adapters."
Write-Host "2. Disables Delayed ACK (TcpAckFrequency) on active adapters."
Write-Host "3. Disables Network Throttling (NetworkThrottlingIndex)."
Write-Host "4. Sets System Responsiveness to Gaming Priority (0)."
Write-Host ""
Write-Host "Target Registry Keys:"
Write-Host "  - HKLM\...\Tcpip\Parameters\Interfaces\{GUID}"
Write-Host "  - $gamingRegPath"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false }

if ($activeAdapters) {
    foreach ($adapter in $activeAdapters) {
        $interfaceGUID = $adapter.InterfaceGuid
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$interfaceGUID"

        try {
            if (Test-Path $regPath) {
                Set-ItemProperty -Path $regPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path $regPath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction Stop
                Write-Host "Successfully optimized network adapter: $($adapter.Name)" -ForegroundColor Green
            } else {
                Write-Warning "Registry path missing for: $($adapter.Name)"
            }
        } catch {
            Write-Error "Failed to optimize adapter $($adapter.Name): $_"
        }
    }
} else {
    Write-Warning "No active physical network adapters found."
}

try {
    if (Test-Path $gamingRegPath) {
        Set-ItemProperty -Path $gamingRegPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -ErrorAction Stop
        Write-Host "Successfully set 'NetworkThrottlingIndex' to 0xFFFFFFFF." -ForegroundColor Green

        Set-ItemProperty -Path $gamingRegPath -Name "SystemResponsiveness" -Value 0 -Type DWord -ErrorAction Stop
        Write-Host "Successfully set 'SystemResponsiveness' to 0." -ForegroundColor Green
    } else {
        Write-Warning "Registry path not found: $gamingRegPath"
    }
    Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
} catch {
    Write-Error "Failed to set registry value: $_"
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")