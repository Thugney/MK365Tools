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

## Functions

### Connection Management
- `Connect-MK365User`: Establishes connection to Microsoft Graph API
  ```powershell
  Connect-MK365User -TenantId "your-tenant-id" -Interactive
  ```

### User Management
- `Get-MK365UserOverview`: Retrieves user information
  ```powershell
  Get-MK365UserOverview -UserPrincipalName "user@domain.com" -Detailed
  ```

- `New-MK365User`: Creates a new Microsoft 365 user
  ```powershell
  New-MK365User -DisplayName "John Doe" -UserPrincipalName "john@domain.com" -Password "SecurePass123!" -Department "IT"
  ```

- `Set-MK365UserProperties`: Updates user properties
  ```powershell
  Set-MK365UserProperties -UserPrincipalName "user@domain.com" -DisplayName "New Name" -Department "HR"
  ```

- `Remove-MK365User`: Removes a user
  ```powershell
  Remove-MK365User -UserPrincipalName "user@domain.com"
  ```

### Group Management
- `Add-MK365UserToGroup`: Adds a user to a group
  ```powershell
  Add-MK365UserToGroup -UserPrincipalName "user@domain.com" -GroupId "group-id"
  ```

- `Remove-MK365UserFromGroup`: Removes a user from a group
  ```powershell
  Remove-MK365UserFromGroup -UserPrincipalName "user@domain.com" -GroupId "group-id"
  ```

- `Get-MK365UserGroups`: Lists groups a user belongs to
  ```powershell
  Get-MK365UserGroups -UserPrincipalName "user@domain.com"
  ```

### Security Management
- `Get-MK365UserSignInStatus`: Retrieves user sign-in status
  ```powershell
  Get-MK365UserSignInStatus -UserPrincipalName "user@domain.com"
  ```

- `Reset-MK365UserPassword`: Resets a user's password
  ```powershell
  Reset-MK365UserPassword -UserPrincipalName "user@domain.com" -NewPassword "NewSecurePass123!" -ForceChangePasswordNextSignIn
  ```

- `Enable-MK365MFA`: Enables Multi-Factor Authentication for a user
  ```powershell
  Enable-MK365MFA -UserPrincipalName "user@domain.com"
  ```

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
