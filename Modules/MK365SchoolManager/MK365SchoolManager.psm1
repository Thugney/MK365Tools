# MK365SchoolManager.psm1
#Requires -Version 5.1

function Install-RequiredModule {
    param (
        [string]$ModuleName,
        [string]$RequiredVersion
    )
    
    try {
        $module = Get-Module -Name $ModuleName -ListAvailable | 
            Where-Object { $_.Version -eq $RequiredVersion }
        
        if (-not $module) {
            Write-Host "Installing $ModuleName version $RequiredVersion..."
            
            # Ensure we have access to PSGallery
            $gallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
            if (-not $gallery) {
                Write-Host "Registering PSGallery..."
                Register-PSRepository -Default -ErrorAction Stop
            }
            
            # Try to find the module in PSGallery
            $moduleInGallery = Find-Module -Name $ModuleName -RequiredVersion $RequiredVersion -ErrorAction Stop
            if ($moduleInGallery) {
                # Install the module
                $moduleInGallery | Install-Module -Force -AllowClobber -ErrorAction Stop
                Write-Host "Successfully installed $ModuleName"
            }
            else {
                throw "Module $ModuleName version $RequiredVersion not found in PSGallery"
            }
        }
        
        # Import the module
        Import-Module -Name $ModuleName -RequiredVersion $RequiredVersion -Force -ErrorAction Stop
        Write-Host "Successfully loaded $ModuleName version $RequiredVersion"
        return $true
    }
    catch {
        Write-Warning "Error with module $ModuleName`: $_"
        return $false
    }
}

function Initialize-MK365Dependencies {
    [CmdletBinding()]
    param()
    
    $success = $true
    
    # Install NuGet if needed
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Host "Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    }
    
    # Required modules with their versions
    $modules = @(
        @{ Name = 'Microsoft.Graph.Authentication'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Identity.DirectoryManagement'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Users'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Groups'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Beta.DeviceManagement'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Administration'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Actions'; Version = '2.25.0' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Functions'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Enrollment'; Version = '2.26.1' },
        @{ Name = 'MK365DeviceManager'; Version = '1.0.0' }
    )
    
    foreach ($module in $modules) {
        if (-not (Install-RequiredModule -ModuleName $module.Name -RequiredVersion $module.Version)) {
            $success = $false
        }
    }
    
    if (-not $success) {
        Write-Warning "Some required modules could not be installed. The module may not function correctly."
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
        Write-Error "Error connecting to Microsoft Graph: $_"
        throw
    }
}

# Function to disconnect from Microsoft Graph
function Disconnect-MK365School {
    [CmdletBinding()]
    param()
    
    try {
        $context = Get-MgContext
        if ($context) {
            Disconnect-MgGraph
            Write-Verbose "Successfully disconnected from Microsoft Graph"
        }
        else {
            Write-Verbose "No active Microsoft Graph connection found"
        }
    }
    catch {
        Write-Error "Error disconnecting from Microsoft Graph: $_"
        throw
    }
}

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

# Export public functions and connection functions
Export-ModuleMember -Function @(
    'Connect-MK365School',
    'Disconnect-MK365School',
    $Public.BaseName
)
