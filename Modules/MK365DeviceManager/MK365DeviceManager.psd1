# MK365DeviceManager Module Manifest
@{
    RootModule = 'MK365DeviceManager.psm1'
    ModuleVersion = '1.1.0'
    GUID = 'a1b2c3d4-e5f6-4708-b9e0-31c2d3a4b5c6'
    Author = 'Thugney'
    CompanyName = 'MK365Tools'
    Copyright = '(c) 2025 Thugney. All rights reserved.'
    Description = 'Development version of MK365DeviceManager - A PowerShell module for managing Microsoft 365 devices through Microsoft Graph API'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.Intune'; ModuleVersion = '6.1907.1.0'}
    )
    FunctionsToExport = @(
        'Connect-MK365Device',
        'Get-MK365DeviceOverview',
        'Get-MK365SecurityStatus',
        'Get-MK365SecurityBaseline',
        'Get-MK365UpdateCompliance',
        'Get-MK365SystemStatus',
        'Get-MK365AppDeploymentStatus',
        'Register-MK365AutopilotDevices'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Microsoft365', 'DeviceManagement', 'Intune', 'Graph', 'Development')
            ProjectUri = 'https://github.com/Thugney/MK365Tools'
            LicenseUri = 'https://github.com/Thugney/MK365Tools/blob/main/LICENSE'
        }
    }
}
