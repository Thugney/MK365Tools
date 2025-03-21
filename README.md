# MK365Tools - Microsoft 365 Management Tools

[![GitHub Release](https://img.shields.io/github/v/release/Thugney/MK365Tools)](https://github.com/Thugney/MK365Tools/releases/latest)
[![License](https://img.shields.io/github/license/Thugney/MK365Tools)](https://github.com/Thugney/MK365Tools/blob/main/LICENSE)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/MK365Tools)](https://www.powershellgallery.com/packages/MK365Tools)
[![Twitter Follow](https://img.shields.io/twitter/follow/eriteach?style=social)](https://twitter.com/eriteach)

A comprehensive PowerShell module collection for managing Microsoft 365 devices, users, security, and compliance through Microsoft Graph API.

## Installation

1. Clone the repository:
```powershell
git clone https://github.com/Thugney/MK365Tools.git
cd MK365Tools
```

2. Import the modules:
```powershell
# Import modules (dependencies will be installed automatically)
Import-Module .\Modules\MK365DeviceManager\MK365DeviceManager.psd1
Import-Module .\Modules\MK365UserManager\MK365UserManager.psd1
Import-Module .\Modules\MK365SchoolManager\MK365SchoolManager.psd1

# Or add the module path to PSModulePath for persistent access
$env:PSModulePath = $env:PSModulePath + ";$PWD\Modules"
```

## Dependencies

The modules will automatically install and manage their required dependencies. Here are the key dependencies:

- Microsoft.Graph.Authentication (2.26.1)
- Microsoft.Graph.DeviceManagement (2.26.1)
- Microsoft.Graph.Intune (6.1907.1.0)
- Microsoft.Graph.Identity.DirectoryManagement (2.26.1)
- Microsoft.Graph.Users (2.26.1)
- Microsoft.Graph.Groups (2.26.1)
- Microsoft.Graph.Beta.DeviceManagement (2.26.1)
- Microsoft.Graph.DeviceManagement.Administration (2.26.1)
- Microsoft.Graph.DeviceManagement.Actions (2.25.0)
- Microsoft.Graph.DeviceManagement.Functions (2.26.1)
- Microsoft.Graph.DeviceManagement.Enrollment (2.26.1)
- Microsoft.Graph.Identity.SignIns (2.26.1)

## Version
Stable version: 1.1.0

## Features

### School Management (MK365SchoolManager)
- Comprehensive school device lifecycle management
- Automated device reset workflows
- Device inventory tracking and reporting
- School-specific configuration management
- Bulk device operations with detailed logging
- Integration with education-specific features

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
- Automatic dependency management
- Smart module version handling

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

## Prerequisites

### Microsoft Graph PowerShell SDK
The modules require the following Microsoft Graph PowerShell modules (v2.26.1):
- Microsoft.Graph.Authentication
- Microsoft.Graph.DeviceManagement
- Microsoft.Graph.Identity.DirectoryManagement
- Microsoft.Graph.Users
- Microsoft.Graph.Groups
- Microsoft.Graph.Beta.DeviceManagement
- Microsoft.Graph.DeviceManagement.Administration
- Microsoft.Graph.DeviceManagement.Actions (v2.25.0)
- Microsoft.Graph.DeviceManagement.Functions
- Microsoft.Graph.DeviceManagement.Enrollment
- Microsoft.Graph.Identity.SignIns
- Microsoft.Graph.Intune

## Quick Start

### School Management
```powershell
# Connect to Microsoft Graph
Connect-MK365School

# Get device inventory
Get-MK365DeviceInventory -GroupName "School Devices"

# Start device reset workflow
Start-MK365ResetWorkflow -DeviceId "DEVICE-ID" -ResetType "Wipe"

# Configure school settings
Set-MK365SchoolConfig -ConfigPath "path\to\config.json"
```

### User Management
```powershell
# Connect to Microsoft Graph
Connect-MK365User

# Create a new user
New-MK365User -UserPrincipalName "user@domain.com" -DisplayName "New User"

# Get user information
Get-MK365UserInfo -UserPrincipalName "user@domain.com"
```

### Device Management
```powershell
# Connect to Microsoft Graph
Connect-MK365Device

# Register Autopilot device
Register-MK365AutopilotDevice -SerialNumber "SERIAL-NUMBER" -GroupTag "School-Devices"

# Get device status
Get-MK365DeviceStatus -SerialNumber "SERIAL-NUMBER"
```

## Module Documentation

Each module has its own detailed documentation:

- [MK365SchoolManager Documentation](./Modules/MK365SchoolManager/README.md)
- [MK365UserManager Documentation](./Modules/MK365UserManager/README.md)
- [MK365DeviceManager Documentation](./Modules/MK365DeviceManager/README.md)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

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