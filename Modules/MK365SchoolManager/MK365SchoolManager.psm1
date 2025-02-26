# MK365SchoolManager.psm1

#Requires -Version 5.1
#Requires -PSEdition Desktop

#Requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.26.1' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.DeviceManagement'; ModuleVersion='2.26.1' }
#Requires -Modules @{ ModuleName='Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion='2.26.1' }
#Requires -Modules @{ ModuleName='MK365DeviceManager'; ModuleVersion='1.0.0' }

# Import all public functions
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName
