# MK365UserManager PowerShell Module

A PowerShell module for managing Microsoft 365 users through Microsoft Graph API. This module provides a comprehensive set of functions for user management, group management, and security settings.

## Prerequisites

- PowerShell 5.1 or later
- Microsoft Graph PowerShell SDK modules:
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.Users
  - Microsoft.Graph.Groups
  - Microsoft.Graph.Identity.SignIns

## Installation

1. Clone this repository or download the module files
2. Import the module:
```powershell
Import-Module .\MK365UserManager.psd1
```

## Features

### User Management
- Create, update, and remove users
- Manage user properties and access settings
- Reset passwords and enable MFA
- Bulk user operations with CSV templates
- User access control and permissions
- User security status monitoring
- Automated user provisioning
- User license management
- Custom attribute management
- User activity tracking

### Group Management
- Add and remove users from groups
- View user group memberships
- Bulk group assignments

### Security Management
- Monitor user sign-in status
- Track security and risk levels
- Manage authentication methods
- Enable and configure MFA

### Reporting
- Generate comprehensive user reports
- Track security compliance
- Monitor group memberships
- Schedule automated reports

### Templates and Scripts
The module includes ready-to-use templates and scripts for common operations:

#### Templates
- `NewUsers.csv` - Template for bulk user creation
- `UserGroupAssignments.csv` - Template for group assignments
- `BulkUserUpdate.csv` - Template for updating user properties

#### Scripts
- `New-BulkUsers.ps1` - Create multiple users from CSV
- `Add-BulkUserGroups.ps1` - Assign users to groups in bulk
- `Get-UserReport.ps1` - Generate user and security reports

For detailed information about templates and scripts, see `Templates/README.md`.

## Functions

### Connection Management
- `Connect-MK365User`: Connects to Microsoft 365
  ```powershell
  # Interactive connection
  Connect-MK365User -Interactive
  
  # Certificate-based authentication
  Connect-MK365User -TenantId "your-tenant-id" -ClientId "your-client-id" -CertificateThumbprint "cert-thumbprint"
  ```

### User Management
- `Get-MK365UserOverview`: Gets overview of users
  ```powershell
  # Get all users
  Get-MK365UserOverview
  
  # Get specific user with detailed info
  Get-MK365UserOverview -UserPrincipalName "user@domain.com" -Detailed
  ```

- `New-MK365User`: Creates a new user
  ```powershell
  New-MK365User -DisplayName "John Doe" `
                -UserPrincipalName "john.doe@contoso.com" `
                -Password "SecurePass123!" `
                -Department "IT" `
                -JobTitle "Systems Engineer" `
                -ForceChangePasswordNextSignIn
  ```

- `Set-MK365UserProperties`: Updates user properties
  ```powershell
  Set-MK365UserProperties -UserPrincipalName "john.doe@contoso.com" `
                         -DisplayName "John A. Doe" `
                         -Department "IT" `
                         -JobTitle "Senior Engineer" `
                         -AccountEnabled $true
  ```

- `Remove-MK365User`: Removes a user
  ```powershell
  Remove-MK365User -UserPrincipalName "user@domain.com"
  ```

### Group Management
- `Add-MK365UserToGroup`: Adds user to a group
  ```powershell
  Add-MK365UserToGroup -UserPrincipalName "user@domain.com" -GroupId "group-id"
  ```

- `Remove-MK365UserFromGroup`: Removes user from a group
  ```powershell
  Remove-MK365UserFromGroup -UserPrincipalName "user@domain.com" -GroupId "group-id"
  ```

- `Get-MK365UserGroups`: Gets groups user belongs to
  ```powershell
  Get-MK365UserGroups -UserPrincipalName "user@domain.com"
  ```

### Access Management
- `Get-MK365UserAccess`: Gets user access information
  ```powershell
  Get-MK365UserAccess -UserPrincipalName "user@domain.com"
  ```

- `Set-MK365UserAccess`: Sets user access settings
  ```powershell
  Set-MK365UserAccess -UserPrincipalName "user@domain.com" -BlockSignIn $false
  ```

### Security Management
- `Get-MK365UserSignInStatus`: Gets user sign-in status
  ```powershell
  Get-MK365UserSignInStatus -UserPrincipalName "user@domain.com"
  ```

- `Get-MK365UserSecurityStatus`: Gets user security information
  ```powershell
  Get-MK365UserSecurityStatus -UserPrincipalName "user@domain.com"
  ```

- `Reset-MK365UserPassword`: Resets user password
  ```powershell
  Reset-MK365UserPassword -UserPrincipalName "user@domain.com" `
                         -NewPassword "NewSecurePass123!" `
                         -ForceChangePasswordNextSignIn
  ```

- `Enable-MK365MFA`: Enables multi-factor authentication
  ```powershell
  Enable-MK365MFA -UserPrincipalName "user@domain.com"
  ```

### Bulk Operations
The module includes scripts for bulk operations:

- `New-BulkUsers.ps1`: Creates multiple users from CSV
  ```powershell
  .\Scripts\New-BulkUsers.ps1 -CsvPath ".\Templates\NewUsers.csv"
  ```

- `Add-BulkUserGroups.ps1`: Adds users to groups in bulk
  ```powershell
  .\Scripts\Add-BulkUserGroups.ps1 -CsvPath ".\Templates\UserGroupAssignments.csv"
  ```

## Report Generation

### Basic Reports
```powershell
# Generate basic user report
Get-UserReport.ps1 -OutputPath "Reports\UserReport.csv"

# Include group memberships
Get-UserReport.ps1 -OutputPath "Reports\UserGroups.csv" -IncludeGroups

# Full security audit
Get-UserReport.ps1 -OutputPath "Reports\SecurityAudit.csv" -IncludeGroups -IncludeSecurity
```

### Automated Reports
Schedule regular reports using Windows Task Scheduler:
```powershell
# Create daily report task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\Scripts\Get-UserReport.ps1`" -OutputPath `"$PWD\Reports\DailyReport.csv`""
$trigger = New-ScheduledTaskTrigger -Daily -At 6AM
Register-ScheduledTask -TaskName "M365 Daily User Report" -Action $action -Trigger $trigger
```

### Report Management
- Reports are generated in the `Reports` directory
- Report files are automatically excluded from git
- Implement your organization's backup and retention policies

## Error Handling

All functions include comprehensive error handling and will:
- Verify Microsoft Graph connection before executing operations
- Provide detailed error messages when operations fail
- Support verbose output for debugging (`-Verbose` parameter)

## Best Practices

1. Always use secure passwords and follow your organization's password policies
2. Use the `-Verbose` parameter when troubleshooting
3. Test operations in a non-production environment first
4. Use `ShouldProcess` support for destructive operations (e.g., `Remove-MK365User -WhatIf`)

## Contributing

Feel free to submit issues and enhancement requests!
