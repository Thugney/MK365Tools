# MK365Tools - Microsoft 365 Device Management PowerShell Module

[![GitHub](https://img.shields.io/github/license/Thugney/MK365Tools)](https://github.com/Thugney/MK365Tools/blob/main/LICENSE)
[![Twitter Follow](https://img.shields.io/twitter/follow/eriteach?style=social)](https://twitter.com/eriteach)

A comprehensive PowerShell module for managing Microsoft 365 devices, security, and compliance through Microsoft Graph API.

## Features

### Device Management
- Device overview and reporting
- Autopilot device registration
- Device compliance monitoring
- Group assignment management

### Security & Compliance
- Security baseline assessment
- Security status monitoring
- Update compliance tracking
- System status monitoring

### Application Management
- Application deployment status
- Installation tracking
- Compliance reporting

## Installation

```powershell
# Clone the repository
git clone https://github.com/Thugney/MK365Tools.git

# Import the module
Import-Module .\Modules\MK365DeviceManager\MK365DeviceManager.psm1
```

## Usage

### Device Overview
```powershell
# Get device overview with export
Get-MK365DeviceOverview -ExportReport -ReportFormat HTML
```

### Security Status
```powershell
# Check security status
Get-MK365SecurityStatus -ExportReport
```

### System Status
```powershell
# Monitor Microsoft 365 services
Get-MK365SystemStatus -IncludeAdvisories -ExportReport
```

### Update Compliance
```powershell
# Check update compliance
Get-MK365UpdateCompliance -ExportReport
```

## Available Functions

### Core Management
- `Connect-MK365Device` - Establish connection to Microsoft Graph API
- `Get-MK365DeviceOverview` - Get comprehensive device overview
- `Export-MK365DeviceReport` - Export detailed device reports

### Autopilot Management
- `Export-MK365AutopilotDevices` - Export Autopilot device information
- `Register-MK365AutopilotDevices` - Register devices with Autopilot

### Compliance & Security
- `Get-MK365DeviceCompliance` - Check device compliance status
- `Get-MK365SecurityBaseline` - Assess security baseline compliance
- `Get-MK365SecurityStatus` - Monitor security status
- `Get-MK365UpdateCompliance` - Track update compliance

### Application Management
- `Get-MK365AppDeploymentStatus` - Monitor app deployment status

### Group Management
- `Set-MK365DeviceGroupAssignment` - Manage device group assignments

### System Monitoring
- `Get-MK365SystemStatus` - Monitor Microsoft 365 service health

## Requirements

- PowerShell 5.1 or higher
- Microsoft Graph PowerShell SDK
- Required Microsoft Graph API permissions:
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementConfiguration.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All
  - SecurityEvents.Read.All
  - Group.ReadWrite.All

## Author

- GitHub: [@Thugney](https://github.com/Thugney)
- Twitter: [@eriteach](https://twitter.com/eriteach)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.