# Windows Tweaks

A collection of PowerShell scripts designed to optimize Windows performance, reduce latency, and improve privacy by disabling online search integrations.

## Disclaimer

**Use these scripts at your own risk.** These scripts make changes to your system configuration and **do not include a mechanism to reverse actions**. It is highly recommended to create a System Restore Point before proceeding.

## Requirements

*   **Operating System:** Windows 10 or Windows 11
*   **Permissions:** Administrator privileges (recommended).
*   **PowerShell:** Version 5.1 or newer.

## Scripts

| Script | Purpose | Upside | Downside |
| :--- | :--- | :--- | :--- |
| **Add-Daily-50Day-Uptime-Reboot-Task.ps1** | Reboots system when uptime reaches 50 days. | Enforces periodic restarts so monthly Windows updates/servicing finalize and long-uptime instability risk is reduced. | Forces reboot when threshold is hit, which can interrupt active work if users ignore the shutdown timer warning. |
| **Add-Monthly-DISM-SFC-Task.ps1** | Schedules monthly DISM and SFC scans. | Automates periodic system image and file integrity repair checks with no manual effort. | Can take a long time and cause temporary CPU/disk usage spikes during scans. |
| **Add-Optimized-PowerPlan.ps1** | Creates a heat-optimized power plan. | Lowers heat and fan noise; can make sustained loads easier to manage. | May reduce peak performance because it suppresses Turbo Boost on many CPUs. |
| **Add-Windows-PC-Manager-Preferences.ps1** | Installs Windows PC Manager and enables key app preferences. | Automates install and forces AutoUpdate, SelfStart, and App Usage telemetry flags to enabled. | Depends on Winget and modifies app config under ProgramData; future app updates may overwrite values. |
| **Add-Winget-AutoUpdate-Task.ps1** | Auto-updates apps at login via Winget. | Keeps apps current automatically with minimal manual effort. | Can add login-time disk/network activity and may install updates you did not want yet. |
| **Disable-8Dot3-Filenames.ps1** | Disables 8.3 short filename generation. | Reduces file system overhead and improves performance by eliminating legacy name format creation. | Some legacy applications may depend on 8.3 filename support. |
| **Disable-Dell-Services.ps1** | Disables common non-essential Dell background services (for Dell systems only). | Reduces Dell background service overhead and startup noise from SupportAssist/Data Vault/Trusted Device/Optimizer components. | Can disable Dell diagnostics, remediation workflows, and some OEM utility features you may still use. |
| **Disable-HPET.ps1** | Disables High Precision Event Timer and Dynamic Tick. | Can reduce latency or stutter on some systems. | Often has no measurable benefit and can cause timing issues on a few setups. |
| **Disable-Memory-Integrity.ps1** | Turns off Memory Integrity (Core Isolation). | Can improve compatibility or reduce overhead on some systems. | Lowers kernel-level protection and weakens security against certain exploits. |
| **Disable-Menu-Delay.ps1** | Removes the menu animation delay by setting MenuShowDelay to 0 for all profiles. | Makes desktop and context menus feel more responsive system-wide. | Some users may find instant menu opening too abrupt compared to the default delay. |
| **Disable-Window-Animations.ps1** | Disables minimize/maximize window animations by setting MinAnimate to 0 for all profiles. | Makes window transitions feel snappier and reduces visual animation overhead system-wide. | Removes smooth animation effects that some users prefer for visual feedback. |
| **Disable-MMAgent-MemoryCompression.ps1** | Disables Windows Memory Compression. | May reduce CPU overhead from memory compression on some machines. | Uses more RAM and can hurt performance on systems with limited memory. |
| **Disable-Online-Start-Menu-Search.ps1** | Disables Bing/Online results in Start Menu. | Makes Start Menu search more private and local-only. | Removes web results and online suggestions from Start Menu search. |
| **Disable-Startup-Delay.ps1** | Removes artificial startup delay. | Startup apps can launch sooner after sign-in. | Can cause a brief resource spike or lag while many startup apps open at once. |
| **Disable-Telemetry.ps1** | Reduces Windows tracking/telemetry. | Reduces background reporting and some data collection. | Can interfere with Intune, Insider builds, diagnostics, or Microsoft-managed environments. |
| **Enable-Long-Paths.ps1** | Enables support for paths > 260 chars. | Helps with deep folder structures and modern dev/build workflows. | Some legacy tools still assume the old path limit and may behave inconsistently. |
| **Enable-Quake-Mode.ps1** | Auto-starts Terminal in Quake mode. | Gives fast drop-down terminal access at login. | Adds another startup component and may be unnecessary if you do not use Terminal often. |
| **Enable-Seconds-On-Taskbar-Clock.ps1** | Shows seconds in the system tray clock. | Gives more precise time visibility without opening a clock app. | Adds visual clutter and requires an Explorer restart or sign-out to take effect. |
| **Optimize-FSUtil-MemoryUsage.ps1** | Optimizes file system memory usage (level 2). | Allows Windows to use more memory for file caching, improving disk I/O performance. | Can increase memory usage; may have minimal impact on systems with efficient caching already. |
| **Reduce-Latency.ps1** | Optimizes network/system for gaming latency. | Can improve responsiveness for latency-sensitive gaming or networking workloads. | May increase battery usage and can trade throughput or efficiency for lower latency. |

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
If you see an error stating that "running scripts is disabled on this system", or if the script immediately closes after running, you can run the script with the Execution Policy bypass flag:

```powershell
powershell -ExecutionPolicy Bypass -File .\Disable-Startup-Delay.ps1
```
