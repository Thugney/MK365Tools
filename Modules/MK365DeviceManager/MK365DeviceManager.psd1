@{
    ModuleVersion = '0.1.0'
    GUID = 'f8b0e1d5-7a1d-4e75-8b1a-8d9f5e1d5a7c'
    Author = 'MK365 Tools'
    CompanyName = 'MK365'
    Copyright = '(c) 2025 MK365. All rights reserved.'
    Description = 'PowerShell module for managing Intune and Autopilot devices'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Intune'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement'; ModuleVersion = '2.0.0'}
    )
    FunctionsToExport = @(
        'Connect-MK365Device',
        'Get-MK365DeviceOverview',
        'Export-MK365AutopilotDevices',
        'Register-MK365AutopilotDevices',
        'Get-MK365DeviceCompliance',
        'Get-MK365AppDeploymentStatus',
        'Get-MK365SecurityBaseline',
        'Export-MK365DeviceReport',
        'Set-MK365DeviceGroupAssignment',
        'Get-MK365SecurityStatus',
        'Get-MK365UpdateCompliance'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Intune', 'Autopilot', 'DeviceManagement', 'Microsoft365')
            ProjectUri = ''
            LicenseUri = ''
        }
    }
}
