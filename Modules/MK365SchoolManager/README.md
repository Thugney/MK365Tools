# MK365SchoolManager

A PowerShell module for automating school device lifecycle management in Microsoft 365 environments. Part of the MK365Tools suite.

## Features

- 📱 Comprehensive device inventory management
- 🔄 Automated device reset workflows
- 📊 Detailed reporting and tracking
- ⚙️ Flexible configuration system
- 🏫 Multi-school support
- 📅 Scheduled operations
- 📧 Stakeholder notifications

## Prerequisites

- PowerShell 5.1 or later
- Microsoft Graph PowerShell SDK
- MK365DeviceManager module
- Appropriate Microsoft 365 permissions:
  - DeviceManagementManagedDevices.ReadWrite.All
  - Device.ReadWrite.All
  - Directory.ReadWrite.All
  - Group.Read.All

## Installation

```powershell
# Clone the repository
git clone https://github.com/Thugney/MK365Tools.git

# Import the module
Import-Module .\Modules\MK365SchoolManager\MK365SchoolManager.psd1
```

## Quick Start

1. **Connect to Microsoft Graph**
```powershell
Connect-MK365Device
```

2. **Configure the module**
```powershell
Set-MK365SchoolConfig -School "Example School" `
                      -GradeLevels "7","10" `
                      -NotificationEmails "it@school.com"
```

3. **Get device inventory**
```powershell
Get-MK365DeviceInventory -DeviceType All -ExportReport
```

4. **Start reset workflow**
```powershell
Start-MK365ResetWorkflow -GradeLevels "7","10" -NotifyStakeholders
```

## Configuration

The module uses a JSON configuration file (`SchoolConfig.json`) for settings:

```json
{
    "School": "Example School",
    "GradeLevels": ["7", "10"],
    "DeviceModels": {
        "RetireModels": ["Surface Laptop 2"],
        "KeepModels": ["Surface Laptop 4", "Surface Laptop 3"]
    },
    "NotificationEmails": ["it@school.com"]
}
```

## Common Scenarios

### End of Year Device Reset

1. **Prepare inventory report**
```powershell
# Get current device status
$devices = Get-MK365DeviceInventory -GradeLevels "7","10" -ExportReport
```

2. **Review and plan**
```powershell
# Identify devices to reset
$devices | Where-Object { $_.Model -in $config.DeviceModels.RetireModels }
```

3. **Execute reset workflow**
```powershell
# Start the reset process
Start-MK365ResetWorkflow -GradeLevels "7","10" -NotifyStakeholders
```

### Device Lifecycle Management

1. **Track device status**
```powershell
# Get device overview
Get-MK365DeviceInventory -IncludeDetails | 
    Select-Object Model, @{
        Name='AgeInYears'; 
        Expression={
            (New-TimeSpan -Start $_.EnrollmentDate -End (Get-Date)).Days / 365
        }
    }
```

2. **Plan replacements**
```powershell
# Identify old devices
$oldDevices = Get-MK365DeviceInventory | 
    Where-Object { $_.Model -in $config.DeviceModels.RetireModels }
```

## Best Practices

1. **Before Reset Season**
   - Update device inventory
   - Verify configurations
   - Test on sample devices
   - Notify stakeholders

2. **During Reset Process**
   - Monitor progress
   - Keep stakeholders informed
   - Document issues
   - Track completion

3. **After Reset Completion**
   - Verify device status
   - Update inventory
   - Archive reports
   - Document lessons learned

## Error Handling

The module includes comprehensive error handling:

```powershell
try {
    Start-MK365ResetWorkflow -GradeLevels "7","10" -ErrorAction Stop
} catch {
    Write-Error "Reset failed: $_"
    Get-MK365ResetStatus | Export-Csv "reset_error_log.csv"
}
```

## Reporting

Generate detailed reports:

```powershell
# Device inventory report
Get-MK365DeviceInventory -ExportReport

# Reset status report
Get-MK365ResetStatus -Detailed | 
    Export-Csv "reset_status_report.csv"
```

## Advanced Usage

### Custom Workflows

Create custom reset workflows:

```powershell
# Custom reset for specific models
$devices = Get-MK365DeviceInventory |
    Where-Object { $_.Model -eq "Surface Laptop 2" }

Start-MK365ResetWorkflow -Devices $devices `
                        -CustomSettings @{
                            KeepUserData = $false
                            RemoveAutoPilot = $true
                            NotifyUsers = $true
                        }
```

### Scheduled Operations

Set up scheduled tasks:

```powershell
$trigger = New-ScheduledTaskTrigger -AtTime "2025-06-01T18:00:00" -Once
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-Command Start-MK365ResetWorkflow -GradeLevels '7','10' -NotifyStakeholders"

Register-ScheduledTask -TaskName "SchoolDeviceReset" `
                      -Trigger $trigger `
                      -Action $action
```

## Troubleshooting

Common issues and solutions:

1. **Connection Issues**
   ```powershell
   # Verify connection
   Get-MK365ConnectionStatus
   # Reconnect if needed
   Connect-MK365Device -Force
   ```

2. **Reset Failures**
   ```powershell
   # Get failed devices
   Get-MK365ResetStatus | 
       Where-Object Status -eq 'Failed'
   ```

3. **Disk Space Issues**
   ```powershell
   # Check disk space
   Get-MK365DeviceInventory | 
       Where-Object { $_.StorageFree -lt 10 }
   ```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines.

## Support

For issues and feature requests, please use the GitHub issue tracker.
