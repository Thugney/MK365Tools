# MK365SchoolManager Workflow Guide

## Overview

The MK365SchoolManager module provides specialized tools for managing school devices throughout their lifecycle, with a particular focus on the end-of-year reset and redistribution process. This guide explains how to use the module effectively and how the reset workflow operates.

## Prerequisites

Before using the MK365SchoolManager module, ensure you have:

1. PowerShell 5.1 or higher
2. The following Microsoft Graph PowerShell modules installed:
   - Microsoft.Graph.Authentication
   - Microsoft.Graph.DeviceManagement
   - Microsoft.Graph.Users

## Getting Started

### Installation

```powershell
# Import the module
Import-Module MK365SchoolManager

# Connect to Microsoft Graph with required permissions
Connect-MK365School
```

### Basic Configuration

```powershell
# Set up basic school configuration
Set-MK365SchoolConfig -School "Example School" -GradeLevels "7","10"

# Configure device models for lifecycle management
$deviceModels = @{
    RetireModels = @("Surface Laptop 2")
    KeepModels = @("Surface Laptop 4", "Surface Laptop 3")
}
Set-MK365SchoolConfig -DeviceModels $deviceModels
```

## Reset Workflow Explained

The `Start-MK365ResetWorkflow` function is the core of the module, providing an end-to-end solution for resetting and preparing devices for reuse.

### How Grade Level Filtering Works

When you specify grade levels using the `-GradeLevels` parameter (e.g., `"7","10"`), the workflow:

1. Retrieves all managed devices using `Get-MK365DeviceInventory`
2. Examines the Azure AD groups that each device's user belongs to
3. Identifies groups with names that match grade patterns (e.g., "7A", "10B")
4. Selects only devices where the user is in the specified grades

This is particularly useful for:
- End of middle school (grade 7) transitions
- End of secondary education (grade 10) transitions
- Any grade-based device collection scenario

### Device Eligibility Criteria

Before processing any device, the workflow checks these eligibility criteria:

| Category | Criteria | Reason |
|----------|----------|--------|
| Management | Device is Compliant | Ensures device is in a known good state |
| Management | Device is Managed | Confirms Intune can control the device |
| Device State | Has valid device name | Required for identification |
| Device State | Has serial number | Required for AutoPilot |
| Device State | Has Azure AD device ID | Required for Azure operations |
| Storage | Has >0 total storage | Confirms storage is readable |
| Storage | Has ≥5GB free space | Ensures space for reset operation |
| Connectivity | Synced within 30 days | Confirms device is active |
| User | Has assigned user | Required for grade-based filtering |

### Reset Process Steps

For each eligible device, the workflow performs these operations:

1. **Initiate Device Wipe**
   - Uses `Invoke-MgWipeDeviceManagementManagedDevice`
   - Configures wipe to remove all user data and enrollment

2. **Remove from AutoPilot**
   - Identifies the device by serial number
   - Removes it from Windows AutoPilot

3. **Remove from Azure AD**
   - Removes the device record from Azure AD

4. **Update Device Category**
   - Changes category to "Reset Pending" for tracking

5. **Track Status**
   - Maintains lists of successful, failed, pending, and ineligible devices

### Notification System

When using the `-NotifyStakeholders` parameter, the workflow:

1. Generates a comprehensive report with:
   - Timestamp and school information
   - Grade levels processed
   - Device counts by status
   - Detailed device information

2. Exports the report to JSON format

3. Emails the report to IT staff (configurable via `Set-MK365SchoolConfig`)

## Testing the Workflow

To safely test the reset workflow without making changes:

```powershell
# Test with WhatIf to see what would happen
Start-MK365ResetWorkflow -GradeLevels "7","10" -WhatIf -Verbose
```

To test with a single device:

```powershell
# Identify a test device
$testDevice = Get-MK365DeviceInventory | Select-Object -First 1

# Run reset on just this device
Start-MK365ResetWorkflow -DeviceSerialNumbers $testDevice.SerialNumber
```

## Troubleshooting

If you encounter issues with the reset workflow:

1. **Connection Problems**
   - Ensure you're connected with `Connect-MK365School`
   - Verify you have the required permissions

2. **No Eligible Devices**
   - Check the verbose output to see why devices are ineligible
   - Use `Get-MK365DeviceInventory` to examine device properties

3. **Failed Operations**
   - Review the returned results object for details on failures
   - Check the Microsoft Graph API permissions

## Best Practices

1. **Always run with `-WhatIf` first** to preview changes
2. **Use `-Verbose`** to see detailed operation logs
3. **Schedule resets during off-hours** using the `-ScheduledDate` parameter
4. **Create a backup inventory report** before running large-scale resets
5. **Test with a small subset** before processing an entire grade level

## Complete End-of-Year Device Reset Process

### 1. Initial Setup and Configuration

```powershell
# 1.1 Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement
Import-Module MK365DeviceManager
Import-Module MK365SchoolManager

# 1.2 Connect to Microsoft Graph
Connect-MK365Device

# 1.3 Configure school settings
$schoolConfig = @{
    School = "Example School"
    GradeLevels = @("7", "10")
    DeviceModels = @{
        RetireModels = @("Surface Laptop 2", "iPad 7th Generation")
        KeepModels = @("Surface Laptop 4", "Surface Laptop 3")
    }
    NotificationEmails = @("it@school.com", "admin@school.com")
    CustomSettings = @{
        AutoResetEnabled = $true
        MinDiskSpaceGB = 128
    }
}

Set-MK365SchoolConfig @schoolConfig
```

### 2. Pre-Reset Planning Phase

```powershell
# 2.1 Generate current inventory report
$inventory = Get-MK365DeviceInventory -IncludeDetails -ExportReport
Write-Host "Total devices found: $($inventory.Count)"

# 2.2 Analyze devices by grade
$gradeDevices = $inventory | Group-Object Grade | Select-Object Name, Count
$gradeDevices | Format-Table

# 2.3 Check device models to be retired
$retiringModels = Get-MK365SchoolConfig | Select-Object -ExpandProperty DeviceModels | 
    Select-Object -ExpandProperty RetireModels

$devicesToRetire = $inventory | Where-Object { 
    $_.Model -in $retiringModels -or
    $_.Grade -in @("7", "10")
}

# 2.4 Generate planning report
$planningReport = [PSCustomObject]@{
    TotalDevices = $inventory.Count
    DevicesToReset = $devicesToRetire.Count
    ByGrade = $gradeDevices
    ByModel = $devicesToRetire | group-Object Model | Select-Object Name, Count
    LowStorage = $devicesToRetire | Where-Object { $_.StorageFree -lt 10 }
}

$planningReport | ConvertTo-Json -Depth 5 | Out-File "reset_planning.json"
```

### 3. Stakeholder Communication

```powershell
# 3.1 Create notification list
$notificationList = @{
    IT = "it@school.com"
    Admin = "admin@school.com"
    Teachers = Get-TeacherEmails -Grades "7","10"  # Custom function
}

# 3.2 Send planning notification
$emailParams = @{
    To = $notificationList.Values
    Subject = "Device Reset Planning - $((Get-Date).ToString('yyyy-MM-dd'))"
    Body = @"
Device Reset Planning Report:
- Total Devices: $($planningReport.TotalDevices)
- Devices to Reset: $($planningReport.DevicesToReset)
- Low Storage Devices: $($planningReport.LowStorage.Count)

Please review the attached report and confirm by replying to this email.
"@
    Attachments = "reset_planning.json"
}

Send-MK365Notification @emailParams
```

### 4. Execute Reset Workflow

```powershell
# 4.1 Start the reset process
$resetParams = @{
    GradeLevels = @("7", "10")
    NotifyStakeholders = $true
    ScheduledDate = (Get-Date).AddDays(7)  # Schedule for next week
}

$resetJob = Start-MK365ResetWorkflow @resetParams

# 4.2 Monitor progress
while ($resetJob.Status -eq 'Running') {
    $status = Get-MK365ResetStatus
    
    Write-Progress -Activity "Device Reset Progress" `
                  -Status "Processing devices..." `
                  -PercentComplete (($status.Completed.Count / $status.Total) * 100)
    
    Start-Sleep -Seconds 30
}
```

### 5. Post-Reset Verification

```powershell
# 5.1 Verify reset completion
$finalStatus = Get-MK365ResetStatus -Detailed

# 5.2 Check for failed resets
$failedDevices = $finalStatus | Where-Object Status -eq 'Failed'
if ($failedDevices) {
    # Create remediation plan
    $remediation = foreach ($device in $failedDevices) {
        [PSCustomObject]@{
            SerialNumber = $device.SerialNumber
            Error = $device.ErrorMessage
            Action = if ($device.ErrorMessage -match 'storage') {
                'Manual Reset Required'
            } else {
                'Retry Automated Reset'
            }
        }
    }
    
    $remediation | Export-Csv "remediation_plan.csv"
}

# 5.3 Generate completion report
$completionReport = [PSCustomObject]@{
    CompletedDate = Get-Date
    TotalDevices = $finalStatus.Count
    Successful = ($finalStatus | Where-Object Status -eq 'Completed').Count
    Failed = $failedDevices.Count
    FailedDevices = $remediation
}

$completionReport | ConvertTo-Json | Out-File "reset_completion.json"
```

### 6. System Cleanup

```powershell
# 6.1 Remove from AutoPilot
$completedDevices = $finalStatus | Where-Object Status -eq 'Completed'
foreach ($device in $completedDevices) {
    Remove-AutoPilotDevice -SerialNumber $device.SerialNumber
}

# 6.2 Remove from Azure AD
foreach ($device in $completedDevices) {
    Remove-AzureADDevice -ObjectId $device.AzureADObjectId
}

# 6.3 Update inventory
Get-MK365DeviceInventory -ExportReport -OutputPath "post_reset_inventory.csv"
```

## End-of-Year Device Management Process

The MK365SchoolManager module now includes a comprehensive end-of-year device management solution that automates the entire workflow for resetting and retiring school devices.

### Automated End-of-Year Process

The `Start-MK365EndOfYearProcess` function provides a complete solution for managing devices at the end of the school year:

```powershell
# Basic usage for 7th and 10th grade devices
Start-MK365EndOfYearProcess -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn" -ExportInventoryReports

# Advanced usage with model-based selection
Start-MK365EndOfYearProcess -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn" `
    -ModelsToRetire "Surface Laptop 2","iPad 7th Generation" `
    -ModelsToKeep "Surface Laptop 4","Surface Laptop 3" `
    -IncludeOtherGradesForRetiredModels `
    -NotifyStakeholders `
    -NotificationEmails "it@school.com","admin@school.com" `
    -AutoRemoveFromAutoPilot `
    -AutoRemoveFromAzureAD `
    -ExportInventoryReports
```

This function handles:
1. Identifying devices to reset based on grade levels and/or device models
2. Generating detailed inventory reports
3. Resetting eligible devices
4. Removing devices from AutoPilot and Azure AD
5. Generating comprehensive reports of the entire process

> **Note:** For detailed guidance on model-based device reset, see the [Model-Based Reset Guide](./model-based-reset-guide.md).

#### Available Parameters

| Parameter | Description |
|-----------|-------------|
| School | Name of the school to process |
| GradeLevels | Grade levels to target (default: "7. trinn", "10. trinn") |
| DeviceType | Type of devices to process: PC, iPad, or All (default: All) |
| ModelsToRetire | List of device models that should be reset |
| ModelsToKeep | List of device models that should NOT be reset |
| IncludeOtherGradesForRetiredModels | If set, will also reset devices with the specified models from other grades |
| ExportInventoryReports | Generate detailed inventory reports before and after reset |
| ReportPath | Path where reports should be saved |
| NotifyStakeholders | Send email notifications to stakeholders |
| NotificationEmails | Email addresses to notify |
| AutoRemoveFromAutoPilot | Automatically remove reset devices from AutoPilot |
| AutoRemoveFromAzureAD | Automatically remove reset devices from Azure AD |
| SkipConfirmation | Skip confirmation prompts |
| ScheduledDate | Schedule the reset for a future date |

### School Group Management

The `Get-MK365SchoolGroup` function helps identify and manage user groups by school and grade level:

```powershell
# Get all groups for a school
$schoolGroups = Get-MK365SchoolGroup -School "Eksempel Skole"

# Get groups for specific grade levels with member details
$gradeGroups = Get-MK365SchoolGroup -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn" -IncludeMembers

# Export group report
Get-MK365SchoolGroup -School "Eksempel Skole" -ExportReport
```

### Enhanced Device Reporting

The `Get-MK365DeviceReport` function provides detailed reports about school devices:

```powershell
# Generate a basic device report
$deviceReport = Get-MK365DeviceReport -School "Eksempel Skole"

# Generate a detailed report with user and group information
$detailedReport = Get-MK365DeviceReport -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn" `
    -DeviceType "PC" -IncludeUserDetails -IncludeGroupDetails -ExportReport -ReportFormat "Excel"
```

### Retiring Devices

The `Remove-MK365RetiredDevice` function helps remove devices from management systems:

```powershell
# Remove specific devices by serial number
Remove-MK365RetiredDevice -SerialNumbers "ABC123","DEF456" -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults

# Remove devices from a CSV report
Remove-MK365RetiredDevice -CsvReportPath "DevicesToRetire.csv" -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults
```

## Quick Start Commands

### Basic Reset Workflow
```powershell
# One-line command for simple reset
Start-MK365ResetWorkflow -GradeLevels "7","10" -NotifyStakeholders
```

### Advanced Reset Workflow
```powershell
# More controlled reset process
$params = @{
    GradeLevels = "7","10"
    DeviceType = "All"
    ScheduledDate = "2025-06-15"
    NotifyStakeholders = $true
    CustomSettings = @{
        KeepUserData = $false
        RemoveAutoPilot = $true
        NotifyUsers = $true
    }
}

Start-MK365ResetWorkflow @params
```

### Monitoring and Reporting
```powershell
# Monitor progress
Get-MK365ResetStatus

# Generate reports
Get-MK365ResetStatus -Detailed | Export-Excel "reset_report.xlsx"
```

## Common Scenarios

### Scenario 1: Immediate Reset for Specific Grade
```powershell
# Reset all 7th grade devices immediately
Start-MK365ResetWorkflow -GradeLevels "7" -NotifyStakeholders
```

### Scenario 2: Scheduled Reset for Multiple Grades
```powershell
# Schedule reset for end of school year
Start-MK365ResetWorkflow -GradeLevels "7","10" `
                        -ScheduledDate "2025-06-15" `
                        -NotifyStakeholders
```

### Scenario 3: Reset Specific Models
```powershell
# Reset only older device models
$oldModels = (Get-MK365SchoolConfig).DeviceModels.RetireModels
Start-MK365ResetWorkflow -DeviceModels $oldModels -NotifyStakeholders
```

## Error Handling

### Common Issues and Solutions

1. **Insufficient Storage**
```powershell
# Check storage before reset
Get-MK365DeviceInventory | 
    Where-Object { $_.StorageFree -lt 10 } |
    Export-Csv "low_storage_devices.csv"
```

2. **Connection Issues**
```powershell
# Reconnect to services
Connect-MK365Device -Force
```

3. **Failed Resets**
```powershell
# Get failed devices and retry
$failed = Get-MK365ResetStatus | 
    Where-Object Status -eq 'Failed'

Start-MK365ResetWorkflow -Devices $failed -Force
```

## Best Practices

1. **Always run inventory check first**
2. **Notify stakeholders before starting**
3. **Schedule resets during off-hours**
4. **Monitor progress regularly**
5. **Keep detailed logs**
6. **Verify completion**
7. **Document any issues**

## Automation Tips

1. **Create scheduled tasks**
2. **Use error logging**
3. **Implement retry logic**
4. **Monitor storage space**
5. **Track completion status**
