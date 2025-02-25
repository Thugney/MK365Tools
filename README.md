# MK365Tools - Microsoft 365 Device Management PowerShell Module

[![GitHub](https://img.shields.io/github/license/Thugney/MK365Tools)](https://github.com/Thugney/MK365Tools/blob/main/LICENSE)
[![Twitter Follow](https://img.shields.io/twitter/follow/eriteach?style=social)](https://twitter.com/eriteach)

A comprehensive PowerShell module collection for managing Microsoft 365 devices, users, security, and compliance through Microsoft Graph API.

## Features

### User Management (MK365UserManager)
- User lifecycle management (creation, modification, deletion)
- Group membership and access control
- User security and MFA status monitoring
- Bulk user operations with CSV support
- User sign-in and activity tracking

### Device Management (MK365DeviceManager)
- Comprehensive device overview and reporting
- Autopilot device registration with group assignment
- Device compliance and security monitoring
- Enhanced error handling and detailed logging
- Bulk device operations support

### Security & Compliance
- Security baseline assessment and continuous monitoring
- Comprehensive security status tracking with risk assessment
- Update compliance management and reporting
- Real-time system status monitoring
- Security policy enforcement tracking

### Application Management
- Application deployment status tracking
- Installation monitoring with detailed error reporting
- Compliance status reporting with CSV export
- Application configuration management
- Deployment troubleshooting with error code translation

### System Administration
- Service health monitoring with issue tracking
- Detailed error reporting and troubleshooting
- Bulk operations with CSV import/export
- HTML and CSV report generation
- Automated logging and diagnostics

## Installation

```powershell
# Clone the repository
git clone https://github.com/Thugney/MK365Tools.git

# Import the modules
Import-Module .\Modules\MK365DeviceManager\MK365DeviceManager.psm1
Import-Module .\Modules\MK365UserManager\MK365UserManager.psm1
```

## Usage

### User Management
```powershell
# Create a new user
New-MK365User -DisplayName "John Doe" -UserPrincipalName "john.doe@contoso.com"

# Get user's group memberships
Get-MK365UserGroups -UserPrincipalName "john.doe@contoso.com"
```

### Device Management
```powershell
# Get device overview with export
Get-MK365DeviceOverview -ExportReport

# Register Autopilot devices
Register-MK365AutopilotDevices -CsvPath "devices.csv" -AssignToGroup -GroupId "Group-ID"
```

### Security Status
```powershell
# Check security status
Get-MK365SecurityStatus -ComplianceStatus All -ExportReport

# Check security baselines
Get-MK365SecurityBaseline -ComplianceStatus All -ExportReport
```

### Application Management
```powershell
# Monitor app deployments
Get-MK365AppDeploymentStatus -Status All -ExportReport

# Check update compliance
Get-MK365UpdateCompliance -Status All -ExportReport
```

### System Monitoring
```powershell
# Monitor Microsoft 365 services
Get-MK365SystemStatus -IssueType All -ExportReport
```

## Available Functions

### User Management
- `New-MK365User` - Create new user accounts with detailed properties
- `Set-MK365UserProperties` - Modify existing user properties
- `Remove-MK365User` - Remove user accounts safely
- `Get-MK365UserGroups` - List user group memberships
- `Get-MK365UserSignInStatus` - Check user sign-in and MFA status

### Device Management
- `Connect-MK365Device` - Establish secure connection to Microsoft Graph API
- `Get-MK365DeviceOverview` - Get comprehensive device overview with filtering
- `Register-MK365AutopilotDevices` - Register and assign devices with Autopilot
- `Get-MK365ErrorDescription` - Get detailed error descriptions for troubleshooting
- `Write-M365Log` - Enhanced logging functionality

### Security & Compliance
- `Get-MK365SecurityBaseline` - Assess security baseline compliance
- `Get-MK365SecurityStatus` - Monitor comprehensive security status
- `Get-MK365UpdateCompliance` - Track update compliance with detailed reporting
- `Get-MK365SystemStatus` - Monitor service health with issue tracking

### Application Management
- `Get-MK365AppDeploymentStatus` - Monitor app deployment with status tracking
- `Get-MK365AppConfiguration` - Review app configuration settings

## Requirements

- PowerShell 5.1 or higher
- Microsoft Graph PowerShell SDK
- Required Microsoft Graph API permissions:
  - DeviceManagementApps.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.Read.All
  - Directory.Read.All
  - User.ReadWrite.All
  - Group.Read.All

## Author

- GitHub: [@Thugney](https://github.com/Thugney)
- Twitter: [@eriteach](https://twitter.com/eriteach)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.