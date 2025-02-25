# MK365DeviceManager Usage Guide

## Installation

```powershell
# Import the module
Import-Module .\Modules\MK365DeviceManager\MK365DeviceManager.psm1

# List all available functions
Get-Command -Module MK365DeviceManager
```

## Common Usage Scenarios

### 1. Initial Connection
```powershell
# Connect to Microsoft Graph (required before using other functions)
Connect-MK365Device
```

### 2. Device Management
```powershell
# Get device overview with HTML report
Get-MK365DeviceOverview -ExportReport -ReportFormat HTML

# Export device report
Export-MK365DeviceReport -OutputFormat HTML

# Check device compliance
Get-MK365DeviceCompliance -ExportReport
```

### 3. Security Monitoring
```powershell
# Check security status
Get-MK365SecurityStatus -ExportReport

# Get security baseline assessment
Get-MK365SecurityBaseline -ExportReport

# Monitor update compliance
Get-MK365UpdateCompliance -ExportReport
```

### 4. System Status
```powershell
# Get comprehensive system status
Get-MK365SystemStatus -IncludeAdvisories -ExportReport -ReportFormat Both

# Monitor specific service
Get-MK365SystemStatus -ServiceFilter Intune -LastDays 30
```

### 5. Application Management
```powershell
# Check app deployment status
Get-MK365AppDeploymentStatus -ExportReport
```

### 6. Autopilot Management
```powershell
# Export Autopilot devices
Export-MK365AutopilotDevices -OutputPath "C:\Reports"

# Register new Autopilot devices
Register-MK365AutopilotDevices -CsvPath ".\devices.csv"
```

### 7. Group Management
```powershell
# Assign devices to groups
Set-MK365DeviceGroupAssignment -GroupName "Corporate Devices" -Action Add -DeviceFilter "LAP-*"
```

## Function Parameters

### Get-MK365DeviceOverview
```powershell
Get-MK365DeviceOverview 
    [-ExportReport] 
    [-ReportFormat <CSV|HTML|Both>] 
    [-OutputPath <String>]
```

### Get-MK365SystemStatus
```powershell
Get-MK365SystemStatus 
    [-ServiceFilter <String>] 
    [-IncludeAdvisories] 
    [-LastDays <Int>] 
    [-ExportReport] 
    [-ReportFormat <CSV|HTML|Both>] 
    [-OutputPath <String>]
```

### Get-MK365SecurityStatus
```powershell
Get-MK365SecurityStatus 
    [-ExportReport] 
    [-RiskLevel <Low|Medium|High|All>]
```

### Get-MK365UpdateCompliance
```powershell
Get-MK365UpdateCompliance 
    [-ExportReport] 
    [-UpdateType <Security|Feature|All>]
```

## Tips
1. Always start with `Connect-MK365Device` in a new session
2. Use `-ExportReport` for detailed HTML/CSV reports
3. Check `Get-Help <Function-Name>` for detailed parameter information
4. Use `-Verbose` switch for detailed operation logging
