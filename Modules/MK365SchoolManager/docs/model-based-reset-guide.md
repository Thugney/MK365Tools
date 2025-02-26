# Model-Based Device Reset Guide

## Overview

This guide explains how to use the MK365SchoolManager module to reset devices based on specific models and criteria, particularly for end-of-year device management.

## Understanding the Model-Based Reset Process

The reset process follows these steps:

1. **Inventory Collection**: Gather all devices from specified schools
2. **Model Identification**: Identify device models that should be reset/retired
3. **Condition Assessment**: Filter devices based on their condition metrics
4. **Device Selection**: Select devices based on model, condition, and grade level criteria
5. **Reset Execution**: Reset selected devices
6. **Complete Removal**: Remove reset devices from Intune, AutoPilot, and Entra ID (formerly Azure AD)

## Detailed Configuration Options

### Model Selection Criteria

You can specify exactly which device models should be reset using these parameters:

- **ModelsToRetire**: List of device models that should be reset/retired (e.g., "Surface Laptop 2", "iPad 7th Generation")
- **ModelsToKeep**: List of device models that should NOT be reset, even if they're in target grade levels
- **IncludeOtherGradesForRetiredModels**: If set, will also reset devices with the specified models from other grades (not just 7th and 10th)

### Device Condition Filtering

To filter devices based on their condition, you can use these approaches:

1. **Pre-filtering with custom conditions**:
   ```powershell
   # Get all devices and filter based on condition
   $allDevices = Get-MK365DeviceInventory -School "Eksempel Skole"
   
   # Filter devices with low storage (less than 10GB free)
   $lowStorageDevices = $allDevices | Where-Object { $_.StorageFree -lt 10 }
   
   # Filter devices with battery health issues (less than 70% capacity)
   $batteryIssueDevices = $allDevices | Where-Object { $_.BatteryCapacity -lt 70 }
   
   # Filter devices with multiple failed logins (potential issues)
   $problemDevices = $allDevices | Where-Object { $_.FailedLoginCount -gt 5 }
   
   # Export these devices to a CSV for reset
   $devicesToReset = $lowStorageDevices + $batteryIssueDevices + $problemDevices | Sort-Object -Property SerialNumber -Unique
   $devicesToReset | Export-Csv "DevicesToReset-Condition.csv" -NoTypeInformation
   
   # Use the CSV with the removal function
   Remove-MK365RetiredDevice -CsvReportPath "DevicesToReset-Condition.csv" -RemoveFromAutoPilot -RemoveFromAzureAD
   ```

2. **Using the device report function with condition filters**:
   ```powershell
   # Generate a report with condition filters
   $report = Get-MK365DeviceReport -School "Eksempel Skole" -IncludeConditionMetrics
   
   # Export only devices with condition issues
   $report | Where-Object { 
       $_.StorageFree -lt 10 -or 
       $_.BatteryCapacity -lt 70 -or 
       $_.FailedLoginCount -gt 5 
   } | Export-Csv "DevicesToReset-Condition.csv" -NoTypeInformation
   ```

### System Removal Options

The module provides options to completely remove devices from all management systems:

- **AutoRemoveFromAutoPilot**: Automatically removes reset devices from AutoPilot
- **AutoRemoveFromAzureAD**: Automatically removes reset devices from Entra ID (Azure AD)

These parameters ensure that devices are completely removed from your management systems after reset.

### Example Scenarios

#### Scenario 1: Reset all Surface Laptop 2 devices, regardless of grade

```powershell
Start-MK365EndOfYearProcess -School "Eksempel Skole" `
    -ModelsToRetire "Surface Laptop 2" `
    -IncludeOtherGradesForRetiredModels `
    -ExportInventoryReports
```

#### Scenario 2: Reset only old models used by 7th and 10th grade

```powershell
Start-MK365EndOfYearProcess -School "Eksempel Skole" `
    -GradeLevels "7. trinn","10. trinn" `
    -ModelsToRetire "Surface Laptop 2","iPad 7th Generation" `
    -ExportInventoryReports
```

#### Scenario 3: Reset old models, but keep specific newer models even in 7th and 10th grade

```powershell
Start-MK365EndOfYearProcess -School "Eksempel Skole" `
    -GradeLevels "7. trinn","10. trinn" `
    -ModelsToRetire "Surface Laptop 2","iPad 7th Generation" `
    -ModelsToKeep "Surface Laptop 4","Surface Laptop 3" `
    -ExportInventoryReports
```

#### Scenario 4: Reset and remove all Surface Laptop 2 devices with poor battery health

```powershell
# Step 1: Identify devices with poor battery health
$inventory = Get-MK365DeviceInventory -School "Eksempel Skole" -IncludeDetails
$poorBatteryDevices = $inventory | Where-Object { 
    $_.Model -eq "Surface Laptop 2" -and 
    $_.BatteryCapacity -lt 70 
}

# Step 2: Export to CSV for documentation
$poorBatteryDevices | Export-Csv "PoorBatteryDevices.csv" -NoTypeInformation

# Step 3: Reset and remove these devices
Start-MK365EndOfYearProcess -School "Eksempel Skole" `
    -ModelsToRetire "Surface Laptop 2" `
    -IncludeOtherGradesForRetiredModels `
    -AutoRemoveFromAutoPilot `
    -AutoRemoveFromAzureAD `
    -ExportInventoryReports
```

#### Scenario 5: Reset only devices with specific conditions from 7th and 10th grade

```powershell
# Get devices for specific grades
$gradeDevices = Get-MK365DeviceInventory -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn"

# Filter based on condition
$devicesToReset = $gradeDevices | Where-Object {
    # Storage less than 15GB OR battery health less than 75%
    ($_.StorageFree -lt 15) -or ($_.BatteryCapacity -lt 75) -or
    # OR specific problematic models
    ($_.Model -in @("Surface Laptop 2", "iPad 7th Generation"))
}

# Export for documentation
$devicesToReset | Export-Csv "GradeDevicesToReset.csv" -NoTypeInformation

# Reset these devices and remove from systems
$serialNumbers = $devicesToReset.SerialNumber
Remove-MK365RetiredDevice -SerialNumbers $serialNumbers -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults
```

## Pre-Reset Planning

Before running the reset process, you should:

1. **Generate an inventory report** to identify which models are in use:

```powershell
$inventory = Get-MK365DeviceInventory -School "Eksempel Skole" -IncludeDetails
$modelCounts = $inventory | Group-Object Model | Select-Object Name, Count | Sort-Object Count -Descending
$modelCounts | Format-Table
```

2. **Identify which models should be retired** based on age and specifications

3. **Create a configuration file** to document your criteria:

```powershell
$config = @{
    School = "Eksempel Skole"
    GradeLevels = @("7. trinn", "10. trinn")
    ModelsToRetire = @(
        "Surface Laptop 2",
        "iPad 7th Generation"
    )
    ModelsToKeep = @(
        "Surface Laptop 4",
        "Surface Laptop 3"
    )
    IncludeOtherGradesForRetiredModels = $true
}

# Save configuration for documentation
$config | ConvertTo-Json | Out-File "ResetConfig-$(Get-Date -Format 'yyyyMMdd').json"

# Use configuration with the reset process
Start-MK365EndOfYearProcess @config -ExportInventoryReports -NotifyStakeholders
```

## Verification and Testing

Before running the full reset process, you can use the `-WhatIf` parameter to see what would happen without making any changes:

```powershell
Start-MK365EndOfYearProcess -School "Eksempel Skole" `
    -GradeLevels "7. trinn","10. trinn" `
    -ModelsToRetire "Surface Laptop 2" `
    -WhatIf -Verbose
```

## Complete System Removal Workflow

To ensure devices are completely removed from all management systems:

1. **Reset the devices**:
   ```powershell
   Start-MK365ResetWorkflow -GradeLevels "7. trinn","10. trinn" -DeviceType "PC" -School "Eksempel Skole"
   ```

2. **Remove from all systems**:
   ```powershell
   # Option 1: Using the End-of-Year process (handles everything)
   Start-MK365EndOfYearProcess -School "Eksempel Skole" `
       -GradeLevels "7. trinn","10. trinn" `
       -ModelsToRetire "Surface Laptop 2","iPad 7th Generation" `
       -AutoRemoveFromAutoPilot `
       -AutoRemoveFromAzureAD `
       -ExportInventoryReports
   
   # Option 2: Using the dedicated removal function
   # First, get the devices that were reset
   $resetDevices = Get-MK365DeviceInventory -School "Eksempel Skole" -ResetStatus "Reset"
   
   # Then remove them from all systems
   $serialNumbers = $resetDevices.SerialNumber
   Remove-MK365RetiredDevice -SerialNumbers $serialNumbers -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults
   ```

3. **Verify removal**:
   ```powershell
   # Check for any remaining devices in Intune
   $remainingDevices = Get-MK365DeviceInventory -School "Eksempel Skole" | 
                       Where-Object { $_.SerialNumber -in $serialNumbers }
   
   # Check for any remaining devices in AutoPilot
   $remainingAutoPilot = Get-AutoPilotDevice | 
                         Where-Object { $_.SerialNumber -in $serialNumbers }
   
   # Check for any remaining devices in Entra ID
   $remainingEntraID = Get-AzureADDevice | 
                      Where-Object { $_.DeviceId -in $resetDevices.AzureADDeviceId }
   ```

## Detailed Workflow Steps

1. **Connect to required services**:
   ```powershell
   Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","User.Read.All","Group.Read.All"
   Connect-AzureAD  # Required for Azure AD device removal
   ```

2. **Generate pre-reset inventory report**:
   ```powershell
   Get-MK365DeviceReport -School "Eksempel Skole" -ExportReport -ReportFormat "Excel"
   ```

3. **Identify models to retire**:
   ```powershell
   $inventory = Get-MK365DeviceInventory -School "Eksempel Skole"
   $inventory | Group-Object Model | Select-Object Name, Count | Sort-Object Name
   ```

4. **Run the reset process with specific criteria**:
   ```powershell
   $params = @{
       School = "Eksempel Skole"
       GradeLevels = @("7. trinn", "10. trinn")
       ModelsToRetire = @("Surface Laptop 2", "iPad 7th Generation")
       ModelsToKeep = @("Surface Laptop 4", "Surface Laptop 3")
       IncludeOtherGradesForRetiredModels = $true
       NotifyStakeholders = $true
       AutoRemoveFromAutoPilot = $true
       AutoRemoveFromAzureAD = $true
       ExportInventoryReports = $true
       ReportPath = "C:\Reports\EndOfYear2025"
   }
   
   $results = Start-MK365EndOfYearProcess @params
   ```

5. **Verify results**:
   ```powershell
   # Check how many devices were reset
   $results.ResetResults.Successful.Count
   
   # Check which devices failed
   $results.ResetResults.Failed
   
   # Generate post-reset inventory
   Get-MK365DeviceReport -School "Eksempel Skole" -ExportReport -ReportFormat "Excel"
   ```

## Troubleshooting

If devices fail to reset, check:

1. **Device connectivity**: Devices must be online and connected to the internet
2. **Storage space**: Devices with low storage may fail to reset
3. **Management state**: Devices must be properly enrolled in Intune

For devices that cannot be reset remotely, you can:

1. Generate a report of failed devices:
   ```powershell
   $results.ResetResults.Failed | Export-Csv "FailedResets.csv" -NoTypeInformation
   ```

2. Plan for manual reset when devices are collected
