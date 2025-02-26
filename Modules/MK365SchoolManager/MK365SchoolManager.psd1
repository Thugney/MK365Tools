# MK365SchoolManager Module Manifest
@{
    RootModule = 'MK365SchoolManager.psm1'
    ModuleVersion = '1.1.0'
    GUID = '98765432-dcba-fedc-4321-0fedcba98765'
    Author = 'Thugney'
    CompanyName = 'MK365Tools'
    Copyright = '(c) 2025 Thugney. All rights reserved.'
    Description = 'School device lifecycle management module for Microsoft 365'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.Beta.DeviceManagement'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement.Administration'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement.Actions'; ModuleVersion = '2.25.0'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement.Functions'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'Microsoft.Graph.DeviceManagement.Enrollment'; ModuleVersion = '2.26.1'},
        @{ModuleName = 'MK365DeviceManager'; ModuleVersion = '1.0.0'}
    )
    FunctionsToExport = @(
        # Device Management
        'Get-MK365SchoolDevice',
        'Start-MK365DeviceReset',
        'Remove-MK365SchoolDevice',
        
        # Inventory Management
        'Get-MK365DeviceInventory',
        'Export-MK365DeviceReport',
        
        # Workflow Management
        'Start-MK365ResetWorkflow',
        'Get-MK365ResetStatus',
        
        # Configuration
        'Set-MK365SchoolConfig',
        'Get-MK365SchoolConfig'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Microsoft365', 'Education', 'DeviceManagement', 'Intune', 'Graph', 'Development')
            ProjectUri = 'https://github.com/Thugney/MK365Tools'
            LicenseUri = 'https://github.com/Thugney/MK365Tools/blob/main/LICENSE'
        }
    }
}
