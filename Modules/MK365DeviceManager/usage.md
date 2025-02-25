# MK365DeviceManager Usage Guide

## Table of Contents
- [Installation](#installation)
- [Common Usage Scenarios](#common-usage-scenarios)
- [Real-World Examples](#real-world-examples)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Function Reference](#function-reference)

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

# Export device report with specific filters
Get-MK365DeviceOverview -Filter "OS -eq 'Windows 11'" -ExportReport

# Check device compliance with detailed status
Get-MK365DeviceCompliance -ComplianceType All -ExportReport
```

### 3. Security Monitoring
```powershell
# Comprehensive security check
Get-MK365SecurityStatus -RiskLevel All -ExportReport

# Get security baseline assessment with compliance details
Get-MK365SecurityBaseline -ComplianceStatus All -ExportReport

# Monitor update compliance with focus on security updates
Get-MK365UpdateCompliance -UpdateType Security -ExportReport
```

### 4. System Status
```powershell
# Get comprehensive system status
Get-MK365SystemStatus -IncludeAdvisories -ExportReport -ReportFormat Both

# Monitor specific service with historical data
Get-MK365SystemStatus -ServiceFilter "Intune" -LastDays 30 -IncludeResolved
```

### 5. Application Management
```powershell
# Check all app deployment statuses
Get-MK365AppDeploymentStatus -Status All -ExportReport

# Monitor specific app deployment
Get-MK365AppDeploymentStatus -AppName "Microsoft 365 Apps" -DetailedStatus
```

### 6. Autopilot Management
```powershell
# Export current Autopilot devices
Export-MK365AutopilotDevices -OutputPath "C:\Reports"

# Register new Autopilot devices with group assignment
Register-MK365AutopilotDevices -CsvPath ".\devices.csv" -AssignToGroup -GroupId "Autopilot-Devices"
```

## Real-World Examples

### Scenario 1: New Device Deployment
```powershell
# 1. Register new devices in Autopilot
Register-MK365AutopilotDevices -CsvPath ".\new_devices.csv" -AssignToGroup

# 2. Monitor registration status
Get-MK365AutopilotStatus -GroupId "Autopilot-Devices" -WaitForCompletion

# 3. Verify app deployment
Get-MK365AppDeploymentStatus -GroupId "Autopilot-Devices" -Status All

# 4. Check compliance status
Get-MK365DeviceCompliance -GroupFilter "Autopilot-Devices" -ExportReport
```

### Scenario 2: Security Audit
```powershell
# 1. Export comprehensive security report
$securityReport = Get-MK365SecurityStatus -RiskLevel All -ExportReport

# 2. Check security baselines
Get-MK365SecurityBaseline -NonCompliantOnly -ExportReport

# 3. Verify update status
Get-MK365UpdateCompliance -UpdateType All -ExportReport

# 4. Generate executive summary
New-MK365SecuritySummary -InputPath $securityReport -OutputFormat HTML
```

### Scenario 3: Monthly Maintenance
```powershell
# 1. Check system health
Get-MK365SystemStatus -LastDays 30 -IncludeResolved -ExportReport

# 2. Verify app updates
Get-MK365AppDeploymentStatus -Status "Failed" -ExportReport

# 3. Check device health
Get-MK365DeviceOverview -Filter "HealthStatus -ne 'Healthy'" -ExportReport

# 4. Generate maintenance report
New-MK365MaintenanceReport -LastDays 30 -OutputFormat HTML
```

## Advanced Usage

### Automated Device Management
```powershell
# Create a scheduled task for daily device health check
$scriptBlock = {
    Import-Module MK365DeviceManager
    Connect-MK365Device -Credential $credential
    
    # Check device health
    $unhealthyDevices = Get-MK365DeviceOverview -Filter "HealthStatus -ne 'Healthy'"
    
    # Generate alert for non-compliant devices
    if ($unhealthyDevices) {
        Send-MK365Alert -AlertType "DeviceHealth" -Devices $unhealthyDevices
    }
    
    # Check security status
    Get-MK365SecurityStatus -RiskLevel "High" -ExportReport
}

Register-MK365ScheduledTask -Name "DailyHealthCheck" -ScriptBlock $scriptBlock -Schedule "Daily"
```

### Bulk Operations
```powershell
# Process multiple device groups
$groups = Get-MK365DeviceGroups -Filter "startsWith(displayName, 'Corp-')"
foreach ($group in $groups) {
    # Check compliance
    Get-MK365DeviceCompliance -GroupId $group.Id -ExportReport
    
    # Update group settings
    Set-MK365DeviceGroupPolicy -GroupId $group.Id -PolicyTemplate "Standard"
    
    # Verify app deployments
    Get-MK365AppDeploymentStatus -GroupId $group.Id -Status All
}
```

## Troubleshooting

### Common Issues and Solutions

1. Connection Issues
```powershell
# Verify connection status
$context = Get-MK365ConnectionStatus
if (-not $context.Connected) {
    Connect-MK365Device -Interactive
}
```

2. Permission Issues
```powershell
# Check required permissions
Test-MK365Permissions -Scope "DeviceManagement"

# Request additional permissions if needed
Request-MK365Permissions -Scope "DeviceManagement.Read.All"
```

3. Report Generation Issues
```powershell
# Enable detailed logging
$VerbosePreference = "Continue"
Get-MK365DeviceOverview -ExportReport -Debug
```

### Best Practices

1. Always use error handling
```powershell
try {
    Get-MK365DeviceOverview -ExportReport
} catch {
    Write-Error "Failed to generate device report: $_"
    Send-MK365Alert -AlertType "Error" -Message $_.Exception.Message
}
```

2. Implement retry logic for network operations
```powershell
$maxRetries = 3
$retryCount = 0
do {
    try {
        Get-MK365SystemStatus -ExportReport
        break
    } catch {
        $retryCount++
        Start-Sleep -Seconds ($retryCount * 5)
    }
} while ($retryCount -lt $maxRetries)
```

## Function Reference

### Get-MK365DeviceOverview
```powershell
Get-MK365DeviceOverview 
    [-Filter <String>]
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
    [-IncludeResolved]
    [-ExportReport] 
    [-ReportFormat <CSV|HTML|Both>] 
    [-OutputPath <String>]
```

### Get-MK365SecurityStatus
```powershell
Get-MK365SecurityStatus 
    [-ExportReport] 
    [-RiskLevel <Low|Medium|High|All>]
    [-NonCompliantOnly]
```

### Get-MK365UpdateCompliance
```powershell
Get-MK365UpdateCompliance 
    [-ExportReport] 
    [-UpdateType <Security|Feature|All>]
    [-Status <String>]
```

### Register-MK365AutopilotDevices
```powershell
Register-MK365AutopilotDevices
    [-CsvPath <String>]
    [-AssignToGroup]
    [-GroupId <String>]
    [-WaitForCompletion]
```

## Tips and Best Practices
1. Always start with `Connect-MK365Device` in a new session
2. Use `-ExportReport` for detailed HTML/CSV reports
3. Implement error handling in scripts
4. Use `-Verbose` switch for detailed operation logging
5. Regularly check for module updates
6. Monitor operation logs for potential issues
7. Use scheduled tasks for routine maintenance
8. Implement alerting for critical issues
