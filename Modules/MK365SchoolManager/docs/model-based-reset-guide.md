# Model-Based Device Reset Guide

## Overview

This guide explains how to use the MK365SchoolManager module to reset devices based on specific models and criteria, particularly for end-of-year device management.

## Understanding the Model-Based Reset Process

The reset process follows these steps:

1. **Inventory Collection**: Gather all devices from specified schools
2. **Model Identification**: Identify device models that should be reset/retired
3. **Device Selection**: Select devices based on model and grade level criteria
4. **Reset Execution**: Reset selected devices
5. **Cleanup**: Remove reset devices from AutoPilot and Azure AD

## Detailed Configuration Options

### Model Selection Criteria

You can specify exactly which device models should be reset using these parameters:

- **ModelsToRetire**: List of device models that should be reset/retired (e.g., "Surface Laptop 2", "iPad 7th Generation")
- **ModelsToKeep**: List of device models that should NOT be reset, even if they're in target grade levels
- **IncludeOtherGradesForRetiredModels**: If set, will also reset devices with the specified models from other grades (not just 7th and 10th)

### Grade Level Criteria

- **GradeLevels**: List of grade levels to target (e.g., "7. trinn", "10. trinn")
- **School**: Specify which school to process

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
