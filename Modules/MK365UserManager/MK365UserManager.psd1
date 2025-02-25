@{
    RootModule = 'MK365UserManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '2a9c3f8d-7e3b-4f1a-9e5d-6c8b9a5d7c2e'
    Author = 'Thugney'
    CompanyName = 'MK365Tools'
    Copyright = '(c) 2024 Thugney. All rights reserved.'
    Description = 'Microsoft 365 User Management PowerShell Module'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0'}
    )
    FunctionsToExport = @(
        'Connect-MK365User',
        'Get-MK365UserOverview',
        'New-MK365User',
        'Set-MK365UserProperties',
        'Remove-MK365User',
        'Add-MK365UserToGroup',
        'Remove-MK365UserFromGroup',
        'Get-MK365UserGroups',
        'Get-MK365UserAccess',
        'Set-MK365UserAccess',
        'Get-MK365UserSignInStatus',
        'Get-MK365UserSecurityStatus',
        'Reset-MK365UserPassword',
        'Enable-MK365MFA'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Microsoft365', 'User', 'Management', 'Azure', 'ActiveDirectory')
            ProjectUri = 'https://github.com/Thugney/MK365Tools'
        }
    }
}
