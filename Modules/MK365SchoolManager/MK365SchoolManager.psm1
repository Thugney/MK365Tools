# MK365SchoolManager.psm1
#Requires -Version 5.1

# Set module version for all exported functions
$script:ModuleVersion = '1.1.0'

# Import required modules
function Import-RequiredModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$MinimumVersion
    )
    
    try {
        # Check if module is already imported
        if (Get-Module -Name $ModuleName) {
            Write-Verbose "Module $ModuleName is already imported"
            return $true
        }
        
        # Check if module is available
        $moduleAvailable = Get-Module -Name $ModuleName -ListAvailable
        
        if ($moduleAvailable) {
            if ($MinimumVersion) {
                $moduleAvailable = $moduleAvailable | Where-Object { $_.Version -ge $MinimumVersion }
            }
            
            if ($moduleAvailable) {
                # Import the module
                Import-Module -Name $ModuleName -MinimumVersion $MinimumVersion -Global -ErrorAction Stop
                Write-Verbose "Successfully imported $ModuleName"
                return $true
            }
        }
        
        Write-Warning "Module $ModuleName$(if ($MinimumVersion) { " (minimum version: $MinimumVersion)" }) is not available"
        return $false
    }
    catch {
        Write-Warning "Failed to import module $ModuleName. Error: $($_.Exception.Message)"
        return $false
    }
}

# Initialize dependencies
function Initialize-MK365Dependencies {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing MK365SchoolManager dependencies..."
    
    $success = $true
    
    # Required modules with their versions
    $modules = @(
        @{ Name = 'Microsoft.Graph.Authentication'; Version = '2.17.0' },
        @{ Name = 'Microsoft.Graph.Users'; Version = '2.17.0' },
        @{ Name = 'Microsoft.Graph.DeviceManagement'; Version = '2.17.0' }
    )
    
    foreach ($module in $modules) {
        Write-Verbose "Processing module: $($module.Name)"
        if (-not (Import-RequiredModule -ModuleName $module.Name -MinimumVersion $module.Version)) {
            $success = $false
            Write-Warning "Failed to import $($module.Name)"
        }
    }
    
    if (-not $success) {
        Write-Warning "Some required modules could not be imported. The module may not function correctly."
    }
}

# Run initialization when module is imported
Initialize-MK365Dependencies

# Function to connect to Microsoft Graph for school management
function Connect-MK365School {
    [CmdletBinding()]
    param()
    
    try {
        # Check if already connected
        try {
            $context = Get-MgContext
            if ($context) {
                Write-Verbose "Already connected to Microsoft Graph as $($context.Account)"
                return $context
            }
        }
        catch {
            Write-Verbose "Not connected to Microsoft Graph, initiating connection..."
        }
        
        # Required scopes for school device management
        $requiredScopes = @(
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.Read.All',
            'DeviceManagementManagedDevices.Read.All',
            'DeviceManagementServiceConfig.Read.All',
            'Directory.Read.All',
            'Group.Read.All',
            'User.Read.All'
        )
        
        # Connect to Microsoft Graph
        $context = Connect-MgGraph -Scopes $requiredScopes
        
        # Verify connection
        if (-not $context) {
            throw "Failed to connect to Microsoft Graph"
        }
        
        Write-Verbose "Successfully connected to Microsoft Graph with scopes: $($context.Scopes -join ', ')"
        return $context
    }
    catch {
        Write-Error "Error connecting to Microsoft Graph: $($_.Exception.Message)"
        throw
    }
}

# Function to disconnect from Microsoft Graph
function Disconnect-MK365School {
    [CmdletBinding()]
    param()
    
    try {
        Disconnect-MgGraph
        Write-Verbose "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Error "Error disconnecting from Microsoft Graph: $($_.Exception.Message)"
    }
}

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

# Export public functions and connection functions
Export-ModuleMember -Function 'Connect-MK365School'
Export-ModuleMember -Function 'Disconnect-MK365School'
Export-ModuleMember -Function 'Get-MK365DeviceInventory'
Export-ModuleMember -Function 'Set-MK365SchoolConfig'
Export-ModuleMember -Function 'Start-MK365ResetWorkflow'

# Export aliases if needed
# Export-ModuleMember -Alias *
