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

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script creates a new Power Plan based on 'High Performance'."
Write-Host ""
Write-Host "Settings applied:"
Write-Host "1. Minimum Processor State = 5%"
Write-Host "   Allows the CPU to downclock when idle to reduce heat/power"
Write-Host "   without sacrificing peak performance when needed."
Write-Host ""
Write-Host "2. Maximum Processor State = 99%"
Write-Host "   Prevents the CPU from running at 100% utilization. On many"
Write-Host "   modern CPUs, this effectively disables 'Turbo Boost', which"
Write-Host "   significantly lowers temperatures and fan noise."
Write-Host ""
Write-Host "3. PCI Express Link State Power Management = Off"
Write-Host "   Prevents PCIe devices (like GPUs) from sleeping, which"
Write-Host "   reduces latency and micro-stutters."
Write-Host ""
Write-Host "4. USB Selective Suspend = Disabled"
Write-Host "   Prevents USB ports from powering down, ensuring peripherals"
Write-Host "   remain active and responsive."
Write-Host ""
Write-Host "5. Turn off hard disk after = 0 (Never)"
Write-Host "   Prevents drives from spinning down or entering deep sleep,"
Write-Host "   eliminating wake-up latency."
Write-Host ""
Write-Host "6. Sleep after = 0 (Never)"
Write-Host "   Prevents the system from automatically entering sleep mode,"
Write-Host "   ensuring continuous operation."
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to create and activate this plan..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$newPlanName = "High Performance (Optimized)"

Write-Host "Duplicating High Performance scheme..." -ForegroundColor White
$output = powercfg -duplicatescheme $highPerfGuid 2>&1

# Extract new GUID from output
if ($output -match '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})') {
    $newGuid = $matches[0]
    Write-Host "Created new scheme with GUID: $newGuid" -ForegroundColor Green
} else {
    Write-Error "Failed to create new power scheme. Output: $output"
    exit
}

# Rename the new plan
powercfg -changename $newGuid $newPlanName

# Set Min to 5% (AC and DC)
powercfg -setacvalueindex $newGuid SUB_PROCESSOR PROCTHROTTLEMIN 5
powercfg -setdcvalueindex $newGuid SUB_PROCESSOR PROCTHROTTLEMIN 5

# Set Max to 99% (AC and DC)
powercfg -setacvalueindex $newGuid SUB_PROCESSOR PROCTHROTTLEMAX 99
powercfg -setdcvalueindex $newGuid SUB_PROCESSOR PROCTHROTTLEMAX 99

# Set PCIe Link State Power Management to Off (0)
powercfg -setacvalueindex $newGuid SUB_PCIEXPRESS ASPM 0
powercfg -setdcvalueindex $newGuid SUB_PCIEXPRESS ASPM 0

# Set USB Selective Suspend to Disabled (0)
powercfg -setacvalueindex $newGuid SUB_USB USBSUSPEND 0
powercfg -setdcvalueindex $newGuid SUB_USB USBSUSPEND 0

# Set Turn off hard disk after to 0 (Never)
powercfg -setacvalueindex $newGuid SUB_DISK DISKIDLE 0
powercfg -setdcvalueindex $newGuid SUB_DISK DISKIDLE 0

# Set Sleep after to 0 (Never)
powercfg -setacvalueindex $newGuid SUB_SLEEP STANDBYIDLE 0
powercfg -setdcvalueindex $newGuid SUB_SLEEP STANDBYIDLE 0

# Activate
powercfg -setactive $newGuid
Write-Host "Successfully activated '$newPlanName'." -ForegroundColor Green

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")