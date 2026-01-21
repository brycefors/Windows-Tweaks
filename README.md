# Windows Tweaks

A collection of PowerShell scripts designed to optimize Windows performance, reduce latency, and improve privacy by disabling online search integrations.

## Scripts

| Script | Purpose | Key Actions | Notes |
| :--- | :--- | :--- | :--- |
| **Add-Winget-AutoUpdate-Task.ps1** | Auto-updates apps at login via Winget. | Creates Scheduled Task `WingetAutoUpdateUser` to run `winget upgrade --all`. | Auto-elevates. May consume resources at login. |
| **Disable-Online-Start-Menu-Search.ps1** | Disables Bing/Online results in Start Menu. | Sets `DisableSearchBoxSuggestions` = 1 in HKCU Policies. | Removes web results/weather from Start. |
| **Disable-Startup-Delay.ps1** | Removes artificial startup delay. | Sets `StartupDelayInMSec` & `WaitForIdleState` to 0. | May cause temporary lag at login. |
| **Disable-Telemetry.ps1** | Reduces Windows tracking/telemetry. | Sets `AllowTelemetry`=0; Disables Advertising ID; Disables `DiagTrack`. | Auto-elevates. May break Intune/Insider builds. |
| **Enable-Long-Paths.ps1** | Enables support for paths > 260 chars. | Sets `LongPathsEnabled` = 1 in HKLM System. | Auto-elevates. Useful for deep directory structures. |
| **Enable-Seconds-On-Taskbar-Clock.ps1** | Shows seconds in the system tray clock. | Sets `ShowSecondsInSystemClock` = 1 in HKCU Advanced. | Requires Explorer restart or sign out. |
| **Reduce-Latency.ps1** | Optimizes network/system for gaming latency. | Disables Nagle's Algo, Delayed ACK, Network Throttling. | Auto-elevates. May increase battery usage. |

## How to Run

1. Open **PowerShell**.
2. Navigate to the folder containing these scripts:
   ```powershell
   cd "path\to\Windows-Tweaks"
   ```
3. Run a script by typing `.\` followed by the filename:
   ```powershell
   .\Disable-Startup-Delay.ps1
   ```

> **Note:** A **system restart** is recommended after running these scripts (especially `Reduce-Latency.ps1` and `Disable-Startup-Delay.ps1`) to ensure all registry changes and service configurations take effect.

### Troubleshooting
If you see an error stating that "running scripts is disabled on this system", you can run the script with the Execution Policy bypass flag:

```powershell
powershell -ExecutionPolicy Bypass -File .\Disable-Startup-Delay.ps1
```
