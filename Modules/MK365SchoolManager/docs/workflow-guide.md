# MK365SchoolManager Workflow Guide

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
    ByModel = $devicesToRetire | Group-Object Model | Select-Object Name, Count
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
