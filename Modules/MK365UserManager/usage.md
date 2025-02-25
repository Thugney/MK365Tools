# MK365UserManager Usage Guide

This guide provides detailed examples and use cases for the MK365UserManager PowerShell module.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Common Scenarios](#common-scenarios)
  - [User Creation and Setup](#user-creation-and-setup)
  - [User Access Management](#user-access-management)
  - [Security Management](#security-management)
  - [Group Management](#group-management)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Prerequisites

1. PowerShell 5.1 or later
2. Microsoft Graph PowerShell SDK modules:
   ```powershell
   Install-Module Microsoft.Graph.Authentication -Force
   Install-Module Microsoft.Graph.Users -Force
   Install-Module Microsoft.Graph.Groups -Force
   Install-Module Microsoft.Graph.Identity.SignIns -Force
   ```

## Installation

1. Clone the repository:
   ```powershell
   git clone https://github.com/Thugney/MK365Tools.git
   ```

2. Import the module:
   ```powershell
   Import-Module .\Modules\MK365UserManager\MK365UserManager.psd1
   ```

## Common Scenarios

### User Creation and Setup

1. Create a new user with basic information:
   ```powershell
   $newUserParams = @{
       DisplayName = "John Doe"
       UserPrincipalName = "john.doe@contoso.com"
       Password = "SecurePass123!"
       Department = "IT"
       JobTitle = "Systems Engineer"
       ForceChangePasswordNextSignIn = $true
   }
   New-MK365User @newUserParams
   ```

2. Update user properties:
   ```powershell
   Set-MK365UserProperties -UserPrincipalName "john.doe@contoso.com" `
                          -Department "Engineering" `
                          -JobTitle "Senior Systems Engineer"
   ```

### User Access Management

1. View current user access:
   ```powershell
   Get-MK365UserAccess -UserPrincipalName "john.doe@contoso.com"
   ```

2. Grant administrative roles:
   ```powershell
   Set-MK365UserAccess -UserPrincipalName "john.doe@contoso.com" `
                       -AddDirectoryRoles @("Helpdesk Administrator", "User Administrator")
   ```

3. Block user sign-in:
   ```powershell
   Set-MK365UserAccess -UserPrincipalName "john.doe@contoso.com" -BlockSignIn $true
   ```

### Security Management

1. Enable MFA for a user:
   ```powershell
   Enable-MK365MFA -UserPrincipalName "john.doe@contoso.com"
   ```

2. Check user's security status:
   ```powershell
   Get-MK365UserSecurityStatus -UserPrincipalName "john.doe@contoso.com"
   ```

3. Reset user's password:
   ```powershell
   Reset-MK365UserPassword -UserPrincipalName "john.doe@contoso.com" `
                          -NewPassword "NewSecurePass123!" `
                          -ForceChangePasswordNextSignIn
   ```

### Group Management

1. Add user to multiple groups:
   ```powershell
   $groups = @("IT Staff", "Project X Team", "VPN Users")
   foreach ($groupId in $groups) {
       Add-MK365UserToGroup -UserPrincipalName "john.doe@contoso.com" -GroupId $groupId
   }
   ```

2. View user's group memberships:
   ```powershell
   Get-MK365UserGroups -UserPrincipalName "john.doe@contoso.com"
   ```

## Advanced Usage

### Bulk User Management

1. Create multiple users from CSV:
   ```powershell
   Import-Csv "users.csv" | ForEach-Object {
       $userParams = @{
           DisplayName = $_.DisplayName
           UserPrincipalName = $_.UserPrincipalName
           Password = $_.Password
           Department = $_.Department
           JobTitle = $_.JobTitle
       }
       New-MK365User @userParams
   }
   ```

2. Update security settings for all users in a department:
   ```powershell
   $users = Get-MK365UserOverview | Where-Object { $_.Department -eq "Finance" }
   foreach ($user in $users) {
       Enable-MK365MFA -UserPrincipalName $user.UserPrincipalName
       Get-MK365UserSecurityStatus -UserPrincipalName $user.UserPrincipalName
   }
   ```

## Troubleshooting

### Common Issues

1. Connection Issues:
   ```powershell
   # Verify connection
   $context = Connect-MK365User -Interactive
   if (-not $context) {
       Write-Error "Failed to connect to Microsoft 365"
   }
   ```

2. Permission Issues:
   - Ensure your account has the necessary administrative roles
   - Check user access with:
     ```powershell
     Get-MK365UserAccess -UserPrincipalName "admin@contoso.com"
     ```

### Best Practices

1. Always use the `-Verbose` parameter when troubleshooting:
   ```powershell
   New-MK365User -DisplayName "Test User" -UserPrincipalName "test@contoso.com" -Password "Pass123!" -Verbose
   ```

2. Use `ShouldProcess` for destructive operations:
   ```powershell
   Remove-MK365User -UserPrincipalName "john.doe@contoso.com" -WhatIf
   ```

3. Regular security audits:
   ```powershell
   Get-MK365UserOverview | ForEach-Object {
       Get-MK365UserSecurityStatus -UserPrincipalName $_.UserPrincipalName
   }
   ```
