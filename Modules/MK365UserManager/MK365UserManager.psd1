# MK365UserManager Module Manifest
@{
    RootModule = 'MK365UserManager.psm1'
    ModuleVersion = '1.0.0-dev'
    GUID = 'b2c3d4e5-f6g7-48h9-i0j1-k2l3m4n5o6p7'
    Author = 'Thugney'
    CompanyName = 'MK365Tools'
    Copyright = '(c) 2025 Thugney. All rights reserved.'
    Description = 'Development version of MK365UserManager - A PowerShell module for managing Microsoft 365 users through Microsoft Graph API'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0'}
    )
    FunctionsToExport = @(
        'New-MK365User',
        'Set-MK365UserProperties',
        'Remove-MK365User',
        'Get-MK365UserGroups',
        'Get-MK365UserAccess',
        'Set-MK365UserAccess',
        'Enable-MK365MFA',
        'Get-MK365UserSecurityStatus',
        'Reset-MK365UserPassword',
        'Add-MK365UserToGroup',
        'Get-MK365UserSignInStatus'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Microsoft365', 'UserManagement', 'Graph', 'Development')
            ProjectUri = 'https://github.com/Thugney/MK365Tools'
            LicenseUri = 'https://github.com/Thugney/MK365Tools/blob/main/LICENSE'
        }
    }
}
