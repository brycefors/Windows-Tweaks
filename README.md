# Windows Tweaks

A collection of PowerShell scripts designed to optimize Windows performance, reduce latency, and improve privacy by disabling online search integrations.

## Disclaimer

**Use these scripts at your own risk.** These scripts make changes to your system configuration and **do not include a mechanism to reverse actions**. It is highly recommended to create a System Restore Point before proceeding.

## Requirements

*   **Operating System:** Windows 10 or Windows 11
*   **Permissions:** Administrator privileges (recommended).
*   **PowerShell:** Version 5.1 or newer.

## Scripts

| Script | Purpose | Notes |
| :--- | :--- | :--- |
| **Add-Optimized-PowerPlan.ps1** | Creates a heat-optimized power plan. | Disables Turbo Boost on many CPUs; reduces heat. |
| **Add-Winget-AutoUpdate-Task.ps1** | Auto-updates apps at login via Winget. | Auto-elevates. Runs twice to handle dependencies. |
| **Disable-HPET.ps1** | Disables High Precision Event Timer and Dynamic Tick. | Auto-elevates. Reduces latency/stutter. |
| **Disable-Online-Start-Menu-Search.ps1** | Disables Bing/Online results in Start Menu. | Removes web search results from Start Menu. |
| **Disable-Startup-Delay.ps1** | Removes artificial startup delay. | May cause temporary lag at login. |
| **Disable-Telemetry.ps1** | Reduces Windows tracking/telemetry. | Auto-elevates. May break Intune/Insider builds. |
| **Enable-Long-Paths.ps1** | Enables support for paths > 260 chars. | Auto-elevates. Useful for deep directory structures. |
| **Enable-Seconds-On-Taskbar-Clock.ps1** | Shows seconds in the system tray clock. | Requires Explorer restart or sign out. |
| **Reduce-Latency.ps1** | Optimizes network/system for gaming latency. | Auto-elevates. May increase battery usage. |

## How to Run

1. Open **PowerShell** (Run as Administrator).
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
