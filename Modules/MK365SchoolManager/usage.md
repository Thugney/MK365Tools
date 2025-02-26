# MK365SchoolManager Usage Guide

## Table of Contents

1. [Device Inventory Management](#device-inventory-management)
2. [Reset Workflow](#reset-workflow)
3. [Configuration Management](#configuration-management)
4. [Real-World Scenarios](#real-world-scenarios)
5. [Automation Examples](#automation-examples)

## Device Inventory Management

### Getting Device Overview

```powershell
# Get all devices
Get-MK365DeviceInventory

# Filter by device type
Get-MK365DeviceInventory -DeviceType PC

# Filter by grade level
Get-MK365DeviceInventory -GradeLevels "7","10"

# Export detailed report
Get-MK365DeviceInventory -IncludeDetails -ExportReport
```

### Analyzing Device Status

```powershell
# Get devices with low storage
Get-MK365DeviceInventory | 
    Where-Object { $_.StorageFree -lt 10 } |
    Select-Object SerialNumber, UserName, StorageFree

# Check compliance status
Get-MK365DeviceInventory | 
    Group-Object ComplianceState |
    Select-Object Name, Count
```

## Reset Workflow

### Planning Reset Operations

```powershell
# Identify devices for reset
$devices = Get-MK365DeviceInventory -GradeLevels "7","10"
$config = Get-MK365SchoolConfig

# Filter retiring models
$retiringDevices = $devices | 
    Where-Object { $_.Model -in $config.DeviceModels.RetireModels }

# Preview reset scope
$retiringDevices | 
    Format-Table SerialNumber, Model, UserName, Class
```

### Executing Reset Workflow

```powershell
# Start reset for specific grades
Start-MK365ResetWorkflow -GradeLevels "7","10" -NotifyStakeholders

# Reset specific device models
Start-MK365ResetWorkflow -DeviceModels $config.DeviceModels.RetireModels

# Schedule future reset
$params = @{
    GradeLevels = "7","10"
    ScheduledDate = "2025-06-15"
    NotifyStakeholders = $true
}
Start-MK365ResetWorkflow @params
```

### Monitoring Reset Progress

```powershell
# Get current status
Get-MK365ResetStatus

# Export status report
Get-MK365ResetStatus -Detailed |
    Export-Csv "reset_progress.csv"

# Check failed resets
Get-MK365ResetStatus |
    Where-Object Status -eq 'Failed' |
    Export-Csv "failed_resets.csv"
```

## Configuration Management

### Basic Configuration

```powershell
# Set school details
Set-MK365SchoolConfig -School "Example School" `
                      -GradeLevels "7","10"

# Configure device models
$deviceModels = @{
    RetireModels = @("Surface Laptop 2")
    KeepModels = @("Surface Laptop 4", "Surface Laptop 3")
}
Set-MK365SchoolConfig -DeviceModels $deviceModels

# Set notification preferences
Set-MK365SchoolConfig -NotificationEmails @(
    "it@school.com",
    "admin@school.com"
)
```

### Advanced Configuration

```powershell
# Custom settings
$customSettings = @{
    AutoResetEnabled = $true
    MinDiskSpaceGB = 128
    RetentionDays = 30
    DefaultTimeZone = "Europe/Oslo"
    Language = "nb-NO"
}
Set-MK365SchoolConfig -CustomSettings $customSettings

# Multiple configurations
$schools = @("School1", "School2")
foreach ($school in $schools) {
    Set-MK365SchoolConfig -School $school `
                         -ConfigPath "Config\$school.json"
}
```

## Real-World Scenarios

### End of Year Device Collection

```powershell
# 1. Generate inventory report
$devices = Get-MK365DeviceInventory -ExportReport

# 2. Identify devices for collection
$toCollect = $devices | Where-Object {
    $_.GradeLevel -in "7","10" -or
    $_.Model -in $config.DeviceModels.RetireModels
}

# 3. Create collection plan
$toCollect | Group-Object School, Class |
    Export-Csv "collection_plan.csv"

# 4. Start reset process
Start-MK365ResetWorkflow -Devices $toCollect `
                        -NotifyStakeholders
```

### Device Replacement Planning

```powershell
# 1. Analyze device age
$inventory = Get-MK365DeviceInventory -IncludeDetails
$aged = $inventory | Where-Object {
    $_.Model -in $config.DeviceModels.RetireModels
}

# 2. Group by school and grade
$replacementPlan = $aged | 
    Group-Object School, Class |
    Select-Object Name, Count |
    Export-Csv "replacement_plan.csv"

# 3. Generate cost estimate
$costPerDevice = 1000
$totalCost = ($aged | Measure-Object).Count * $costPerDevice
```

## Automation Examples

### Automated Weekly Report

```powershell
$reportScript = {
    Import-Module MK365SchoolManager
    Connect-MK365Device

    # Generate reports
    $date = Get-Date -Format "yyyy-MM-dd"
    $reports = @{
        Inventory = Get-MK365DeviceInventory -ExportReport
        Storage = Get-MK365DeviceInventory | 
            Where-Object { $_.StorageFree -lt 20 }
        Compliance = Get-MK365DeviceInventory |
            Group-Object ComplianceState
    }

    # Export to Excel
    $reports | Export-Excel "WeeklyReport-$date.xlsx"
}

# Create scheduled task
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8am
Register-ScheduledTask -TaskName "WeeklyDeviceReport" `
                      -Trigger $trigger `
                      -Action $reportScript
```

### Automated Reset Verification

```powershell
$verificationScript = {
    # Get devices pending reset
    $pending = Get-MK365ResetStatus |
        Where-Object Status -eq 'Pending'

    foreach ($device in $pending) {
        # Check device status
        $currentStatus = Get-MK365DeviceInventory |
            Where-Object SerialNumber -eq $device.SerialNumber

        if (-not $currentStatus) {
            # Device no longer appears in inventory
            Update-MK365ResetStatus -Device $device -Status 'Completed'
        } elseif ($device.RetryCount -gt 3) {
            # Too many retries
            Update-MK365ResetStatus -Device $device -Status 'Failed'
            Send-NotificationEmail -Subject "Reset Failed" -Device $device
        }
    }
}
```

### Bulk Operations

```powershell
# Process multiple schools
$schoolConfig = Get-Content "schools.json" | ConvertFrom-Json

foreach ($school in $schoolConfig) {
    # Set school-specific config
    Set-MK365SchoolConfig -School $school.Name `
                         -GradeLevels $school.Grades

    # Start reset workflow
    Start-MK365ResetWorkflow -School $school.Name `
                            -NotifyStakeholders
}

# Track overall progress
Get-MK365ResetStatus | 
    Group-Object School, Status |
    Format-Table Name, Count
```
