# MK365UserManager.psm1
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
        @{ Name = 'Microsoft.Graph.Users'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Groups'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Identity.SignIns'; Version = '2.26.1' }
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

# Function to connect to Microsoft 365
function Connect-MK365User {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $false)]
        [string]$CertificateThumbprint,
        
        [Parameter(Mandatory = $false)]
        [switch]$Interactive
    )
    
    try {
        $params = @{}
        
        if ($TenantId) {
            $params['TenantId'] = $TenantId
        }
        if ($ClientId) {
            $params['ClientId'] = $ClientId
        }
        if ($CertificateThumbprint) {
            $params['CertificateThumbprint'] = $CertificateThumbprint
        }
        if ($Interactive) {
            $params['Interactive'] = $true
        }
        
        # Connect to Microsoft Graph
        Connect-MgGraph @params
        
        # Get and display current connection information
        $context = Get-MgContext
        if ($context) {
            Write-Verbose "Successfully connected to Microsoft 365 tenant: $($context.TenantId)"
            Write-Verbose "Connected as: $($context.Account)"
            return $context
        } else {
            throw "Failed to establish connection to Microsoft Graph"
        }
    }
    catch {
        Write-Error "Failed to connect to Microsoft 365: $_"
        throw
    }
}

# Function to get user overview
function Get-MK365UserOverview {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        if ($UserPrincipalName) {
            # Get specific user
            $user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
            $userInfo = [PSCustomObject]@{
                DisplayName = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                Id = $user.Id
                AccountEnabled = $user.AccountEnabled
                CreatedDateTime = $user.CreatedDateTime
                LastSignInDateTime = $null  # Will be populated if -Detailed switch is used
            }

            if ($Detailed) {
                # Get sign-in information
                $signIns = Get-MgUserSignInActivity -UserId $user.Id -ErrorAction SilentlyContinue
                if ($signIns) {
                    $userInfo.LastSignInDateTime = $signIns.LastSignInDateTime
                }
            }

            return $userInfo
        }
        else {
            # Get all users with basic information
            $users = Get-MgUser -All
            return $users | ForEach-Object {
                [PSCustomObject]@{
                    DisplayName = $_.DisplayName
                    UserPrincipalName = $_.UserPrincipalName
                    Id = $_.Id
                    AccountEnabled = $_.AccountEnabled
                }
            }
        }
    }
    catch {
        Write-Error "Failed to get user overview: $_"
        throw
    }
}

# Function to create a new Microsoft 365 user
function New-MK365User {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$Password,
        
        [Parameter(Mandatory = $false)]
        [string]$Department,
        
        [Parameter(Mandatory = $false)]
        [string]$JobTitle,
        
        [Parameter(Mandatory = $false)]
        [string]$MobilePhone,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceChangePasswordNextSignIn
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Prepare user parameters
        $userParams = @{
            DisplayName = $DisplayName
            UserPrincipalName = $UserPrincipalName
            AccountEnabled = $true
            PasswordProfile = @{
                Password = $Password
                ForceChangePasswordNextSignIn = $ForceChangePasswordNextSignIn.IsPresent
            }
            MailNickname = ($UserPrincipalName -split '@')[0]
        }

        # Add optional parameters if provided
        if ($Department) { $userParams['Department'] = $Department }
        if ($JobTitle) { $userParams['JobTitle'] = $JobTitle }
        if ($MobilePhone) { $userParams['MobilePhone'] = $MobilePhone }

        # Create the user using Microsoft Graph cmdlet
        $newUser = New-MgUser @userParams
        Write-Verbose "Created new user: $($newUser.UserPrincipalName)"
        return $newUser
    }
    catch {
        Write-Error "Failed to create user: $_"
        throw
    }
}

# Function to set user properties
function Set-MK365UserProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $false)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $false)]
        [string]$Department,
        
        [Parameter(Mandatory = $false)]
        [string]$JobTitle,
        
        [Parameter(Mandatory = $false)]
        [string]$MobilePhone,
        
        [Parameter(Mandatory = $false)]
        [bool]$AccountEnabled
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Prepare update parameters
        $updateParams = @{}
        if ($PSBoundParameters.ContainsKey('DisplayName')) { $updateParams['DisplayName'] = $DisplayName }
        if ($PSBoundParameters.ContainsKey('Department')) { $updateParams['Department'] = $Department }
        if ($PSBoundParameters.ContainsKey('JobTitle')) { $updateParams['JobTitle'] = $JobTitle }
        if ($PSBoundParameters.ContainsKey('MobilePhone')) { $updateParams['MobilePhone'] = $MobilePhone }
        if ($PSBoundParameters.ContainsKey('AccountEnabled')) { $updateParams['AccountEnabled'] = $AccountEnabled }

        # Update user using Microsoft Graph cmdlet
        $updatedUser = Update-MgUser -UserId $UserPrincipalName -BodyParameter $updateParams
        Write-Verbose "Updated user properties for: $UserPrincipalName"
        return $updatedUser
    }
    catch {
        Write-Error "Failed to update user properties: $_"
        throw
    }
}

# Function to remove a user
function Remove-MK365User {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Remove user using Microsoft Graph cmdlet
        Remove-MgUser -UserId $UserPrincipalName
        Write-Verbose "Removed user: $UserPrincipalName"
    }
    catch {
        Write-Error "Failed to remove user: $_"
        throw
    }
}

# Function to get user groups
function Get-MK365UserGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Get user's group memberships using Microsoft Graph cmdlet
        $groups = Get-MgUserMemberOf -UserId $UserPrincipalName
        return $groups | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }
    }
    catch {
        Write-Error "Failed to get user groups: $_"
        throw
    }
}

# Function to add user to group
function Add-MK365UserToGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Add user to group using Microsoft Graph cmdlet
        New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $UserPrincipalName
        Write-Verbose "Added user $UserPrincipalName to group $GroupId"
    }
    catch {
        Write-Error "Failed to add user to group: $_"
        throw
    }
}

# Function to remove user from group
function Remove-MK365UserFromGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Remove user from group using Microsoft Graph cmdlet
        Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $UserPrincipalName
        Write-Verbose "Removed user $UserPrincipalName from group $GroupId"
    }
    catch {
        Write-Error "Failed to remove user from group: $_"
        throw
    }
}

# Function to get user sign-in status
function Get-MK365UserSignInStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Get user sign-in information using Microsoft Graph cmdlets
        $user = Get-MgUser -UserId $UserPrincipalName
        $signInActivity = Get-MgUser -UserId $UserPrincipalName -Property SignInActivity | Select-Object -ExpandProperty SignInActivity
        $riskStatus = Get-MgRiskyUser -UserId $user.Id -ErrorAction SilentlyContinue

        return [PSCustomObject]@{
            UserPrincipalName = $UserPrincipalName
            LastSignInDateTime = $signInActivity.LastSignInDateTime
            LastNonInteractiveSignInDateTime = $signInActivity.LastNonInteractiveSignInDateTime
            RiskLevel = $riskStatus.RiskLevel
            RiskState = $riskStatus.RiskState
            AccountEnabled = $user.AccountEnabled
        }
    }
    catch {
        Write-Error "Failed to get user sign-in status: $_"
        throw
    }
}

# Function to enable MFA
function Enable-MK365MFA {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Get user ID
        $userId = (Get-MgUser -UserId $UserPrincipalName).Id

        # Get current authentication methods policy
        $authMethodConfig = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId "MicrosoftAuthenticator"
        
        # Update the policy to include the user
        $newTarget = @{
            targetType = "user"
            id = $userId
            isRegistrationRequired = $true
        }

        # Add the user to the included targets
        $authMethodConfig.AdditionalProperties.includeTargets += $newTarget

        # Update the authentication method policy
        Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
            -AuthenticationMethodConfigurationId "MicrosoftAuthenticator" `
            -BodyParameter @{
                State = "enabled"
                includeTargets = $authMethodConfig.AdditionalProperties.includeTargets
            }
        
        Write-Verbose "MFA enabled for user: $UserPrincipalName"
    }
    catch {
        Write-Error "Failed to enable MFA: $_"
        throw
    }
}

# Function to get user security status
function Get-MK365UserSecurityStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Get user ID
        $user = Get-MgUser -UserId $UserPrincipalName
        
        # Get authentication methods
        $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
        
        # Get risk status
        $riskStatus = Get-MgRiskyUser -UserId $user.Id -ErrorAction SilentlyContinue
        
        # Get sign-in logs (last 7 days)
        $signInLogs = Get-MgAuditLogSignIn -Filter "userId eq '$($user.Id)' and createdDateTime gt $((Get-Date).AddDays(-7).ToString('yyyy-MM-dd'))"

        return [PSCustomObject]@{
            UserPrincipalName = $UserPrincipalName
            AuthenticationMethods = $authMethods | ForEach-Object { $_.AdditionalProperties.'@odata.type' }
            RiskLevel = $riskStatus.RiskLevel
            RiskState = $riskStatus.RiskState
            LastSignInAttempts = $signInLogs | Select-Object -First 5 | ForEach-Object {
                @{
                    DateTime = $_.CreatedDateTime
                    Status = $_.Status
                    Location = $_.Location
                    ClientApp = $_.ClientAppUsed
                }
            }
            MFAEnabled = ($authMethods | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' }) -ne $null
            AccountEnabled = $user.AccountEnabled
        }
    }
    catch {
        Write-Error "Failed to get user security status: $_"
        throw
    }
}

# Function to reset user password
function Reset-MK365UserPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$NewPassword,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceChangePasswordNextSignIn
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Reset password using Microsoft Graph cmdlet
        Update-MgUserPassword -UserId $UserPrincipalName -NewPassword $NewPassword -ForceChangePasswordNextSignIn:$ForceChangePasswordNextSignIn
        Write-Verbose "Reset password for user: $UserPrincipalName"
    }
    catch {
        Write-Error "Failed to reset password: $_"
        throw
    }
}

# Function to get user access information
function Get-MK365UserAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Get user's roles and app permissions
        $user = Get-MgUser -UserId $UserPrincipalName
        $directoryRoles = Get-MgUserMemberOf -UserId $user.Id | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.directoryRole' }
        $appRoleAssignments = Get-MgUserAppRoleAssignment -UserId $user.Id

        return [PSCustomObject]@{
            UserPrincipalName = $UserPrincipalName
            DirectoryRoles = $directoryRoles
            AppRoleAssignments = $appRoleAssignments
            AccountEnabled = $user.AccountEnabled
            SignInRestrictions = @{
                BlockSignIn = -not $user.AccountEnabled
                AllowedLocations = $user.SignInLocation
            }
        }
    }
    catch {
        Write-Error "Failed to get user access information: $_"
        throw
    }
}

# Function to set user access
function Set-MK365UserAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $false)]
        [bool]$BlockSignIn,
        
        [Parameter(Mandatory = $false)]
        [string[]]$AddDirectoryRoles,
        
        [Parameter(Mandatory = $false)]
        [string[]]$RemoveDirectoryRoles
    )
    
    try {
        # Verify Microsoft Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Please run Connect-MK365User first."
        }

        # Update sign-in block status if specified
        if ($null -ne $BlockSignIn) {
            Update-MgUser -UserId $UserPrincipalName -AccountEnabled (-not $BlockSignIn)
        }

        # Add directory roles if specified
        if ($AddDirectoryRoles) {
            foreach ($roleName in $AddDirectoryRoles) {
                $role = Get-MgDirectoryRole | Where-Object { $_.DisplayName -eq $roleName }
                if ($role) {
                    New-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$(Get-MgUser -UserId $UserPrincipalName).Id"
                }
                else {
                    Write-Warning "Role not found: $roleName"
                }
            }
        }

        # Remove directory roles if specified
        if ($RemoveDirectoryRoles) {
            foreach ($roleName in $RemoveDirectoryRoles) {
                $role = Get-MgDirectoryRole | Where-Object { $_.DisplayName -eq $roleName }
                if ($role) {
                    Remove-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -DirectoryObjectId (Get-MgUser -UserId $UserPrincipalName).Id
                }
                else {
                    Write-Warning "Role not found: $roleName"
                }
            }
        }

        # Return updated access information
        return Get-MK365UserAccess -UserPrincipalName $UserPrincipalName
    }
    catch {
        Write-Error "Failed to set user access: $_"
        throw
    }
}

# Export all functions
Export-ModuleMember -Function @(
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