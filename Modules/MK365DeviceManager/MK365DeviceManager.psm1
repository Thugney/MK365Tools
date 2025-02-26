# MK365DeviceManager.psm1
# Module for managing Intune and Autopilot devices

# Import required modules
#Requires -Version 5.1

function Install-RequiredModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredVersion
    )
    
    try {
        $module = Get-Module -Name $ModuleName -ListAvailable | 
            Where-Object { $_.Version -eq $RequiredVersion }
        
        if (-not $module) {
            Write-Verbose "Installing $ModuleName version $RequiredVersion..."
            
            # Ensure NuGet provider is available
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                Write-Verbose "Installing NuGet provider..."
                Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
            }
            
            # Ensure PSGallery is trusted
            if ((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted") {
                Write-Verbose "Setting PSGallery as trusted..."
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
            }
            
            # Try to find the module in PSGallery
            $moduleInGallery = Find-Module -Name $ModuleName -RequiredVersion $RequiredVersion -ErrorAction Stop
            if ($moduleInGallery) {
                # Install the module
                $moduleInGallery | Install-Module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                Write-Verbose "Successfully installed $ModuleName"
            }
            else {
                throw "Module $ModuleName version $RequiredVersion not found in PSGallery"
            }
        }
        
        # Import the module
        Import-Module -Name $ModuleName -RequiredVersion $RequiredVersion -Force -ErrorAction Stop -Verbose:$false
        Write-Verbose "Successfully loaded $ModuleName version $RequiredVersion"
        return $true
    }
    catch {
        Write-Error "Error with module $ModuleName`: $_"
        return $false
    }
}

function Initialize-MK365Dependencies {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )
    
    $success = $true
    
    # Required modules with their versions
    $modules = @(
        @{ Name = 'Microsoft.Graph.Authentication'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Actions'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Functions'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.DeviceManagement.Enrollment'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Identity.DirectoryManagement'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Users'; Version = '2.26.1' },
        @{ Name = 'Microsoft.Graph.Groups'; Version = '2.26.1' }
    )
    
    foreach ($module in $modules) {
        Write-Verbose "Processing module: $($module.Name)"
        if (-not (Install-RequiredModule -ModuleName $module.Name -RequiredVersion $module.Version)) {
            $success = $false
            Write-Warning "Failed to install or load $($module.Name)"
        }
    }
    
    if (-not $success) {
        Write-Warning "Some required modules could not be installed. The module may not function correctly."
    }
}

# Run initialization when module is imported
Initialize-MK365Dependencies

function Write-M365Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Warning' { Write-Warning $logMessage }
        'Error' { Write-Error $logMessage }
        default { Write-Verbose $logMessage -Verbose }
    }
}

function Connect-MK365Device {
    [CmdletBinding()]
    param()
    
    try {
        # Check if already connected
        try {
            $context = Get-MgContext
            if ($context) {
                Write-M365Log "Already connected to Microsoft Graph as $($context.Account)"
                return $context
            }
        }
        catch {
            Write-M365Log "Not connected to Microsoft Graph, initiating connection..."
        }
        
        # Required scopes for device management
        $requiredScopes = @(
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.Read.All',
            'DeviceManagementManagedDevices.Read.All',
            'DeviceManagementServiceConfig.Read.All',
            'Directory.Read.All'
        )
        
        # Connect to Microsoft Graph
        $context = Connect-MgGraph -Scopes $requiredScopes
        
        # Verify connection
        if (-not $context) {
            throw "Failed to connect to Microsoft Graph"
        }
        
        Write-M365Log "Successfully connected to Microsoft Graph with scopes: $($context.Scopes -join ', ')"
        return $context
    }
    catch {
        Write-M365Log "Error connecting to Microsoft Graph: $_" -Level Error
        throw $_
    }
}

function Disconnect-MK365Device {
    [CmdletBinding()]
    param()
    
    try {
        $context = Get-MgContext
        if ($context) {
            Disconnect-MgGraph
            Write-M365Log "Successfully disconnected from Microsoft Graph"
        }
        else {
            Write-M365Log "No active Microsoft Graph connection found"
        }
    }
    catch {
        Write-M365Log "Error disconnecting from Microsoft Graph: $_" -Level Error
        throw $_
    }
}

function Get-MK365DeviceOverview {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ExportReport,
        
        [Parameter()]
        [ValidateSet('CSV', 'HTML', 'Both')]
        [string]$ReportFormat = 'CSV',
        
        [Parameter()]
        [string]$OutputPath = (Get-Location).Path
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving device overview..."
        
        # Get all managed devices using Microsoft Graph cmdlets
        $devices = Get-MgDeviceManagementManagedDevice -All
        
        # Get additional device details
        $deviceDetails = foreach ($device in $devices) {
            $compliancePolicy = Get-MgDeviceManagementDeviceCompliancePolicy -Filter "id eq '$($device.CompliancePolicyId)'" -ErrorAction SilentlyContinue
            $configurationProfile = Get-MgDeviceManagementDeviceConfiguration -Filter "id eq '$($device.ConfigurationProfileId)'" -ErrorAction SilentlyContinue
            
            [PSCustomObject]@{
                DeviceName = $device.DeviceName
                SerialNumber = $device.SerialNumber
                OS = $device.OperatingSystem
                OSVersion = $device.OsVersion
                Owner = $device.ManagedDeviceOwnerType
                Compliance = $device.ComplianceState
                LastSync = $device.LastSyncDateTime
                Manufacturer = $device.Manufacturer
                Model = $device.Model
                CompliancePolicy = $compliancePolicy.DisplayName
                ConfigurationProfile = $configurationProfile.DisplayName
                SupervisorStatus = $device.IsSupervised
                EncryptionStatus = $device.EncryptionState
                ManagementAgent = $device.ManagementAgent
                JoinType = $device.JoinType
                EnrollmentType = $device.EnrollmentType
                AADRegistered = $device.AzureADRegistered
                AutoPilotEnrolled = $device.AutoPilotEnrolled
                UserPrincipalName = $device.UserPrincipalName
            }
        }
        
        # Create overview object with enhanced details
        $overview = @{
            TotalDevices = $devices.Count
            LastUpdated = Get-Date
            
            OperatingSystem = $devices | Group-Object -Property OperatingSystem | ForEach-Object {
                [PSCustomObject]@{
                    OS = $_.Name
                    Count = $_.Count
                    Percentage = [math]::Round(($_.Count / $devices.Count) * 100, 2)
                }
            }
            
            OwnershipType = $devices | Group-Object -Property ManagedDeviceOwnerType | ForEach-Object {
                [PSCustomObject]@{
                    Type = $_.Name
                    Count = $_.Count
                    Percentage = [math]::Round(($_.Count / $devices.Count) * 100, 2)
                }
            }
            
            ComplianceState = $devices | Group-Object -Property ComplianceState | ForEach-Object {
                [PSCustomObject]@{
                    State = $_.Name
                    Count = $_.Count
                    Percentage = [math]::Round(($_.Count / $devices.Count) * 100, 2)
                }
            }
            
            ManagementState = $devices | Group-Object -Property ManagementState | ForEach-Object {
                [PSCustomObject]@{
                    State = $_.Name
                    Count = $_.Count
                    Percentage = [math]::Round(($_.Count / $devices.Count) * 100, 2)
                }
            }
            
            EnrollmentType = $devices | Group-Object -Property EnrollmentType | ForEach-Object {
                [PSCustomObject]@{
                    Type = $_.Name
                    Count = $_.Count
                    Percentage = [math]::Round(($_.Count / $devices.Count) * 100, 2)
                }
            }
            
            DeviceDetails = $deviceDetails
        }
        
        # Export report if requested
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            
            # Export CSV if requested
            if ($ReportFormat -in 'CSV', 'Both') {
                $csvPath = Join-Path $OutputPath "DeviceOverview-$timestamp.csv"
                $overview.DeviceDetails | Export-Csv -Path $csvPath -NoTypeInformation
                Write-M365Log "CSV report exported to: $csvPath"
            }
            
            # Export HTML if requested
            if ($ReportFormat -in 'HTML', 'Both') {
                $htmlPath = Join-Path $OutputPath "DeviceOverview-$timestamp.html"
                
                # Create HTML report with enhanced styling and charts
                $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Device Overview Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #2c3e50; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f5f6fa; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .summary { margin-bottom: 30px; }
        .chart { margin: 20px 0; }
        .status-good { color: #27ae60; }
        .status-warning { color: #f39c12; }
        .status-error { color: #c0392b; }
        .card {
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 15px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>Device Overview Report</h1>
    <p>Generated: $($overview.LastUpdated)</p>
    
    <div class="card">
        <h2>Summary</h2>
        <p>Total Devices: $($overview.TotalDevices)</p>
    </div>

    <div class="summary">
        <h2>Operating System Distribution</h2>
        <canvas id="osChart"></canvas>
        <table>
            <tr><th>Operating System</th><th>Count</th><th>Percentage</th></tr>
            $(foreach ($os in $overview.OperatingSystem) {
                "<tr><td>$($os.OS)</td><td>$($os.Count)</td><td>$($os.Percentage)%</td></tr>"
            })
        </table>
    </div>

    <div class="summary">
        <h2>Compliance State</h2>
        <canvas id="complianceChart"></canvas>
        <table>
            <tr><th>State</th><th>Count</th><th>Percentage</th></tr>
            $(foreach ($state in $overview.ComplianceState) {
                "<tr><td>$($state.State)</td><td>$($state.Count)</td><td>$($state.Percentage)%</td></tr>"
            })
        </table>
    </div>

    <div class="summary">
        <h2>Device Details</h2>
        <table>
            <tr>
                <th>Device Name</th>
                <th>OS</th>
                <th>Version</th>
                <th>Owner</th>
                <th>Compliance</th>
                <th>Last Sync</th>
            </tr>
            $(foreach ($device in $overview.DeviceDetails) {
                "<tr>
                    <td>$($device.DeviceName)</td>
                    <td>$($device.OS)</td>
                    <td>$($device.OSVersion)</td>
                    <td>$($device.Owner)</td>
                    <td>$($device.Compliance)</td>
                    <td>$($device.LastSync)</td>
                </tr>"
            })
        </table>
    </div>

    <script>
        // OS Distribution Chart
        new Chart(document.getElementById('osChart').getContext('2d'), {
            type: 'pie',
            data: {
                labels: [$(($overview.OperatingSystem | ForEach-Object { "'$($_.OS)'" }) -join ',')],
                datasets: [{
                    data: [$(($overview.OperatingSystem | ForEach-Object { $_.Count }) -join ',')],
                    backgroundColor: ['#2ecc71', '#3498db', '#9b59b6', '#e74c3c', '#f1c40f']
                }]
            }
        });

        // Compliance Chart
        new Chart(document.getElementById('complianceChart').getContext('2d'), {
            type: 'doughnut',
            data: {
                labels: [$(($overview.ComplianceState | ForEach-Object { "'$($_.State)'" }) -join ',')],
                datasets: [{
                    data: [$(($overview.ComplianceState | ForEach-Object { $_.Count }) -join ',')],
                    backgroundColor: ['#27ae60', '#e74c3c', '#f39c12']
                }]
            }
        });
    </script>
</body>
</html>
"@
                
                $htmlReport | Out-File -FilePath $htmlPath -Encoding UTF8
                Write-M365Log "HTML report exported to: $htmlPath"
            }
        }
        
        return $overview
    }
    catch {
        Write-M365Log "Error retrieving device overview: $_" -Level Error
        throw $_
    }
}

function Export-MK365AutopilotDevices {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [ValidateSet('CSV', 'JSON')]
        [string]$Format = 'CSV'
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Exporting Autopilot device information..."
        
        # If no output path specified, create one in the current directory
        if (-not $OutputPath) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $OutputPath = Join-Path (Get-Location) "AutopilotDevices-$timestamp.$($Format.ToLower())"
        }
        
        # Get all Autopilot devices with detailed information
        $devices = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All | ForEach-Object {
            [PSCustomObject]@{
                SerialNumber = $_.SerialNumber
                Model = $_.Model
                Manufacturer = $_.Manufacturer
                EnrollmentState = $_.EnrollmentState
                GroupTag = $_.GroupTag
                LastContactDateTime = $_.LastContactDateTime
                ProductKey = $_.ProductKey
                ResourceName = $_.ResourceName
                AzureActiveDirectoryDeviceId = $_.AzureActiveDirectoryDeviceId
            }
        }
        
        # Export based on format
        if ($Format -eq 'CSV') {
            $devices | Export-Csv -Path $OutputPath -NoTypeInformation
        }
        else {
            $devices | ConvertTo-Json | Out-File -FilePath $OutputPath
        }
        
        Write-M365Log "Autopilot device information exported to: $OutputPath"
        return $OutputPath
    }
    catch {
        Write-M365Log "Error exporting Autopilot devices: $_" -Level Error
        throw $_
    }
}

function Register-MK365AutopilotDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CsvPath,
        
        [Parameter()]
        [string]$GroupId,
        
        [Parameter()]
        [switch]$AssignToGroup,
        
        [Parameter()]
        [switch]$WaitForRegistration
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Starting Autopilot device registration process..."
        
        # Verify CSV file exists and has required headers
        if (-not (Test-Path $CsvPath)) {
            throw "CSV file not found: $CsvPath"
        }
        
        $devices = Import-Csv -Path $CsvPath
        $requiredHeaders = @('SerialNumber', 'HardwareIdentifier')
        $missingHeaders = $requiredHeaders | Where-Object { $_ -notin $devices[0].PSObject.Properties.Name }
        if ($missingHeaders) {
            throw "CSV file missing required headers: $($missingHeaders -join ', ')"
        }
        
        Write-M365Log "Found $($devices.Count) devices in CSV file"
        
        # Process each device
        $registeredDevices = foreach ($device in $devices) {
            try {
                Write-M365Log "Processing device with serial number: $($device.SerialNumber)"
                
                # Check if device already exists
                $existingDevice = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -Filter "serialNumber eq '$($device.SerialNumber)'"
                if ($existingDevice) {
                    Write-M365Log "Device already registered in Autopilot: $($device.SerialNumber)" -Level Warning
                    continue
                }
                
                # Prepare device registration parameters as a proper BodyParameter
                $autopilotDevice = @{
                    SerialNumber = $device.SerialNumber
                    HardwareIdentifier = $device.HardwareIdentifier
                }
                
                # Add optional parameters only if they exist
                if ($device.ProductKey) { 
                    $autopilotDevice.ProductKey = $device.ProductKey 
                }
                
                if ($device.GroupTag) { 
                    $autopilotDevice.GroupTag = $device.GroupTag 
                }
                
                # Register device using Microsoft Graph with proper BodyParameter
                $newDevice = New-MgDeviceManagementWindowsAutopilotDeviceIdentity -BodyParameter $autopilotDevice

                # If group assignment is requested and GroupId is provided
                if ($AssignToGroup -and $GroupId) {
                    Write-M365Log "Assigning device to group: $GroupId"
                    $groupAssignment = @{
                        "@odata.type" = "#microsoft.graph.windowsAutopilotDeviceIdentity"
                        GroupId = $GroupId
                    }
                    Update-MgDeviceManagementWindowsAutopilotDeviceIdentity -WindowsAutopilotDeviceIdentityId $newDevice.Id -BodyParameter $groupAssignment
                }
                
                # If wait for registration is requested
                if ($WaitForRegistration) {
                    Write-M365Log "Waiting for device registration to complete..."
                    $attempts = 0
                    $maxAttempts = 30
                    $registered = $false
                    
                    do {
                        $deviceStatus = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -WindowsAutopilotDeviceIdentityId $newDevice.Id
                        if ($deviceStatus.EnrollmentState -eq 'enrolled') {
                            $registered = $true
                            Write-M365Log "Device registration completed: $($device.SerialNumber)"
                            break
                        }
                        
                        $attempts++
                        if ($attempts -ge $maxAttempts) {
                            Write-M365Log "Device registration timeout: $($device.SerialNumber)" -Level Warning
                            break
                        }
                        
                        Start-Sleep -Seconds 10
                    } while (-not $registered)
                }
                
                # Return device information
                [PSCustomObject]@{
                    SerialNumber = $device.SerialNumber
                    Id = $newDevice.Id
                    Status = if ($WaitForRegistration) {
                        if ($registered) { "Registered" } else { "Registration Pending" }
                    } else {
                        "Registration Initiated"
                    }
                    GroupAssigned = if ($AssignToGroup -and $GroupId) { $GroupId } else { $null }
                    EnrollmentState = $deviceStatus.EnrollmentState
                    LastContactDateTime = $deviceStatus.LastContactDateTime
                }
            }
            catch {
                Write-M365Log "Error processing device $($device.SerialNumber): $_" -Level Error
                [PSCustomObject]@{
                    SerialNumber = $device.SerialNumber
                    Id = $null
                    Status = "Failed"
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Generate registration summary
        $summary = @{
            TotalDevices = $devices.Count
            Registered = ($registeredDevices | Where-Object Status -eq "Registered").Count
            Pending = ($registeredDevices | Where-Object Status -eq "Registration Initiated").Count
            Failed = ($registeredDevices | Where-Object Status -eq "Failed").Count
            GroupAssignments = if ($AssignToGroup -and $GroupId) {
                ($registeredDevices | Where-Object GroupAssigned -eq $GroupId).Count
            } else {
                0
            }
        }
        
        Write-M365Log "Registration Summary:"
        Write-M365Log "Total Devices: $($summary.TotalDevices)"
        Write-M365Log "Successfully Registered: $($summary.Registered)"
        Write-M365Log "Registration Pending: $($summary.Pending)"
        Write-M365Log "Failed: $($summary.Failed)"
        if ($AssignToGroup -and $GroupId) {
            Write-M365Log "Group Assignments: $($summary.GroupAssignments)"
        }
        
        return [PSCustomObject]@{
            Summary = $summary
            Devices = $registeredDevices
        }
    }
    catch {
        Write-M365Log "Error in Autopilot device registration: $_" -Level Error
        throw $_
    }
}

function Get-MK365DeviceCompliance {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [switch]$IncludeRiskDetails,
        
        [Parameter()]
        [switch]$ExportReport,
        
        [Parameter()]
        [string]$OutputPath = (Get-Location).Path
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving device compliance information..."
        
        # Get all managed devices using proper parameters
        $devices = Get-MgDeviceManagementManagedDevice -All
        
        # Apply filter if specified
        if ($DeviceFilter) {
            $devices = $devices | Where-Object {
                $_.DeviceName -like "*$DeviceFilter*" -or
                $_.SerialNumber -like "*$DeviceFilter*" -or
                $_.UserPrincipalName -like "*$DeviceFilter*"
            }
        }
        
        $complianceReport = $devices | ForEach-Object {
            $compliance = @{
                DeviceName = $_.DeviceName
                SerialNumber = $_.SerialNumber
                UserPrincipalName = $_.UserPrincipalName
                ComplianceState = $_.ComplianceState
                LastSyncDateTime = $_.LastSyncDateTime
                OperatingSystem = $_.OperatingSystem
                OSVersion = $_.OSVersion
                JailBroken = $_.JailBroken
                IsEncrypted = $_.IsEncrypted
                IsSupervised = $_.IsSupervised
            }
            
            if ($IncludeRiskDetails) {
                $compliance.SecurityPatchLevel = $_.SecurityPatchLevel
                $compliance.AadRegistered = $_.AadRegistered
                $compliance.DeviceEnrollmentType = $_.DeviceEnrollmentType
                $compliance.DeviceRegistrationState = $_.DeviceRegistrationState
            }
            
            [PSCustomObject]$compliance
        }
        
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $reportPath = Join-Path $OutputPath "DeviceCompliance-$timestamp.csv"
            $complianceReport | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Compliance report exported to: $reportPath"
        }
        
        return $complianceReport
    }
    catch {
        Write-M365Log "Error retrieving device compliance: $_" -Level Error
        throw $_
    }
}

function Get-MK365AppDeploymentStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$AppName,
        
        [Parameter()]
        [ValidateSet('All', 'Installed', 'Failed', 'Pending')]
        [string]$Status = 'All',
        
        [Parameter()]
        [switch]$ExportReport,
        
        [Parameter()]
        [string]$OutputPath = (Get-Location).Path
    )
    
    try {
        Connect-MK365Device
        Write-M365Log "Retrieving app deployment status..."
        
        # Get all mobile apps using Microsoft Graph
        $apps = Get-MgDeviceAppManagementMobileApp -All
        
        # Filter by app name if specified
        if ($AppName) {
            $apps = $apps | Where-Object { $_.DisplayName -like "*$AppName*" }
        }
        
        $deploymentStatus = foreach ($app in $apps) {
            Write-M365Log "Processing app: $($app.DisplayName)"
            
            # Get app installation states using Microsoft Graph
            $installStates = Get-MgDeviceAppManagementMobileAppInstallStatus -MobileAppId $app.Id
            
            # Filter by status if specified
            if ($Status -ne 'All') {
                $installStates = $installStates | Where-Object { $_.InstallState -eq $Status }
            }
            
            foreach ($state in $installStates) {
                # Get device details using Microsoft Graph
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $state.DeviceId
                
                [PSCustomObject]@{
                    AppName = $app.DisplayName
                    AppId = $app.Id
                    DeviceName = $device.DeviceName
                    DeviceId = $device.Id
                    UserPrincipalName = $device.UserPrincipalName
                    InstallState = $state.InstallState
                    LastModifiedDateTime = $state.LastModifiedDateTime
                    ErrorCode = $state.ErrorCode
                    ErrorDescription = if ($state.ErrorCode) {
                        Get-MK365ErrorDescription -ErrorCode $state.ErrorCode -ErrorType 'AppInstall'
                    } else { $null }
                }
            }
        }

        # Generate summary
        $summary = @{
            TotalApps = $apps.Count
            TotalDevices = ($deploymentStatus | Select-Object DeviceId -Unique).Count
            StatusBreakdown = $deploymentStatus | Group-Object InstallState | ForEach-Object {
                @{
                    Status = $_.Name
                    Count = $_.Count
                }
            }
        }
        
        Write-M365Log "Deployment Status Summary:"
        Write-M365Log "Total Apps: $($summary.TotalApps)"
        Write-M365Log "Total Devices: $($summary.TotalDevices)"
        Write-M365Log "Status Breakdown:"
        foreach ($status in $summary.StatusBreakdown) {
            Write-M365Log "  $($status.Status): $($status.Count)"
        }
        
        # Export report if requested
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $reportPath = Join-Path -Path $OutputPath -ChildPath "AppDeploymentStatus_$timestamp.csv"
            $deploymentStatus | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Report exported to: $reportPath"
        }
        
        return [PSCustomObject]@{
            Summary = $summary
            Details = $deploymentStatus
        }
    }
    catch {
        Write-M365Log "Error retrieving app deployment status: $_" -Level Error
        throw $_
    }
}

function Get-MK365SecurityBaseline {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaselineName,
        
        [Parameter()]
        [ValidateSet('All', 'Compliant', 'NonCompliant', 'Error', 'Conflict')]
        [string]$ComplianceStatus = 'All',
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        Write-M365Log "Retrieving security baseline status..."
        
        # Get security baselines
        $baselines = Get-MgDeviceManagementSecurityBaseline
        if ($BaselineName) {
            $baselines = $baselines | Where-Object { $_.DisplayName -like "*$BaselineName*" }
        }
        
        $baselineStatus = foreach ($baseline in $baselines) {
            Write-M365Log "Processing baseline: $($baseline.DisplayName)"
            
            # Get baseline device states
            $deviceStates = Get-MgDeviceManagementSecurityBaselineDeviceState -SecurityBaselineId $baseline.Id
            
            # Filter by compliance status if specified
            if ($ComplianceStatus -ne 'All') {
                $deviceStates = $deviceStates | Where-Object { $_.Status -eq $ComplianceStatus }
            }
            
            foreach ($state in $deviceStates) {
                # Get device details
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $state.DeviceId
                
                [PSCustomObject]@{
                    BaselineName = $baseline.DisplayName
                    BaselineId = $baseline.Id
                    DeviceName = $device.DeviceName
                    DeviceId = $device.Id
                    UserPrincipalName = $device.UserPrincipalName
                    Status = $state.Status
                    LastSyncDateTime = $state.LastSyncDateTime
                    ErrorCount = $state.ErrorCount
                    ConflictCount = $state.ConflictCount
                    Settings = $state.Settings | ForEach-Object {
                        @{
                            SettingName = $_.SettingName
                            SettingValue = $_.Value
                            Status = $_.Status
                            ErrorCode = $_.ErrorCode
                        }
                    }
                }
            }
        }
        
        # Generate summary
        $summary = @{
            TotalBaselines = $baselines.Count
            TotalDevices = ($baselineStatus | Select-Object DeviceId -Unique).Count
            ComplianceBreakdown = $baselineStatus | Group-Object Status | ForEach-Object {
                @{
                    Status = $_.Name
                    Count = $_.Count
                }
            }
        }
        
        Write-M365Log "Security Baseline Summary:"
        Write-M365Log "Total Baselines: $($summary.TotalBaselines)"
        Write-M365Log "Total Devices: $($summary.TotalDevices)"
        Write-M365Log "Compliance Breakdown:"
        foreach ($status in $summary.ComplianceBreakdown) {
            Write-M365Log "  $($status.Status): $($status.Count)"
        }
        
        # Export report if requested
        if ($ExportReport) {
            $reportPath = Join-Path -Path (Get-Location) -ChildPath "SecurityBaselineStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $baselineStatus | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Report exported to: $reportPath"
        }
        
        return [PSCustomObject]@{
            Summary = $summary
            Details = $baselineStatus
        }
    }
    catch {
        Write-M365Log "Error retrieving security baseline status: $_" -Level Error
        throw $_
    }
}

function Export-MK365DeviceReport {
    <#
    .SYNOPSIS
    Generates a comprehensive device management report combining data from multiple sources.

    .DESCRIPTION
    The Export-MK365DeviceReport function creates a detailed report covering device status,
    security compliance, application deployment, and configuration profiles. It combines data
    from various Intune management areas into a single, comprehensive report.

    .PARAMETER OutputPath
    Optional. The path where the report should be saved. If not specified, creates a file in the current directory.

    .PARAMETER Format
    Optional. The format of the report. Valid values are 'HTML' or 'CSV'. Default is 'HTML'.

    .PARAMETER IncludeInactiveDevices
    Switch parameter. When specified, includes devices that haven't checked in for more than 30 days.

    .PARAMETER DetailLevel
    Optional. The level of detail to include in the report. Valid values are 'Basic', 'Standard', or 'Detailed'.
    Default is 'Standard'.

    .EXAMPLE
    Export-MK365DeviceReport
    Generates a standard HTML report in the current directory.

    .EXAMPLE
    Export-MK365DeviceReport -Format CSV -DetailLevel Detailed
    Generates a detailed CSV report with all available information.

    .EXAMPLE
    Export-MK365DeviceReport -IncludeInactiveDevices -OutputPath "C:\Reports\DeviceReport.html"
    Generates an HTML report including inactive devices at the specified location.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementManagedDevices.Read.All
    - DeviceManagementConfiguration.Read.All
    - DeviceManagementApps.Read.All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [ValidateSet('HTML', 'CSV')]
        [string]$Format = 'HTML',
        
        [Parameter()]
        [switch]$IncludeInactiveDevices,
        
        [Parameter()]
        [ValidateSet('Basic', 'Standard', 'Detailed')]
        [string]$DetailLevel = 'Standard'
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Generating device management report..."
        
        # If no output path specified, create one in the current directory
        if (-not $OutputPath) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $OutputPath = Join-Path (Get-Location) "DeviceReport-$timestamp.$($Format.ToLower())"
        }
        
        # Gather all required data
        $deviceOverview = Get-MK365DeviceOverview
        $complianceStatus = Get-MK365DeviceCompliance
        $securityBaselines = Get-MK365SecurityBaseline
        $appDeployments = Get-MK365AppDeploymentStatus
        
        # Process device data
        $devices = Get-MgDeviceManagementManagedDevice -All
        if (-not $IncludeInactiveDevices) {
            $thirtyDaysAgo = (Get-Date).AddDays(-30)
            $devices = $devices | Where-Object { $_.LastSyncDateTime -gt $thirtyDaysAgo }
        }
        
        $reportData = @{
            GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            DeviceSummary = @{
                TotalDevices = $devices.Count
                ActiveDevices = ($devices | Where-Object { $_.LastSyncDateTime -gt (Get-Date).AddDays(-7) }).Count
                CompliantDevices = ($devices | Where-Object { $_.ComplianceState -eq 'compliant' }).Count
                NonCompliantDevices = ($devices | Where-Object { $_.ComplianceState -eq 'noncompliant' }).Count
            }
            SecuritySummary = @{
                EncryptedDevices = ($devices | Where-Object { $_.IsEncrypted }).Count
                SupervisedDevices = ($devices | Where-Object { $_.IsSupervised }).Count
                JailBrokenDevices = ($devices | Where-Object { $_.JailBroken }).Count
            }
            OSDistribution = $devices | Group-Object -Property OperatingSystem | Select-Object Name, Count
            OwnershipTypes = $devices | Group-Object -Property ManagedDeviceOwnerType | Select-Object Name, Count
        }
        
        # Generate alerts
        $alerts = @()
        
        # Check for critical security issues
        $jailbrokenDevices = $devices | Where-Object { $_.JailBroken }
        if ($jailbrokenDevices) {
            $alerts += @{
                Severity = 'Critical'
                Category = 'Security'
                Message = "Found $($jailbrokenDevices.Count) jailbroken devices"
                AffectedDevices = $jailbrokenDevices.DeviceName
            }
        }
        
        # Check for non-compliant security baselines
        $nonCompliantBaselines = $securityBaselines | Where-Object { $_.Summary.NonCompliant -gt 0 }
        foreach ($baseline in $nonCompliantBaselines) {
            $alerts += @{
                Severity = 'Warning'
                Category = 'Compliance'
                Message = "$($baseline.DisplayName): $($baseline.Summary.NonCompliant) non-compliant devices"
                AffectedDevices = $baseline.DeviceStates | Where-Object { $_.ComplianceState -eq 'noncompliant' } | ForEach-Object { $_.DeviceName }
            }
        }
        
        # Check for failed app deployments
        $failedApps = $appDeployments | Where-Object { $_.Summary.Failed -gt 0 }
        foreach ($app in $failedApps) {
            $alerts += @{
                Severity = 'Warning'
                Category = 'Applications'
                Message = "$($app.DisplayName): Failed to install on $($app.Summary.Failed) devices"
                AffectedDevices = $app.DeviceStatus | Where-Object { $_.InstallState -eq 'failed' } | ForEach-Object { $_.DeviceName }
            }
        }
        
        if ($Format -eq 'HTML') {
            # Load HTML template
            $templatePath = Join-Path $PSScriptRoot "Templates\DeviceReport.html"
            $template = Get-Content -Path $templatePath -Raw
            
            # Generate executive summary
            $executiveSummaryHtml = @"
            <div class="metric-box">
                <h3>Total Devices</h3>
                <div class="value">$($reportData.DeviceSummary.TotalDevices)</div>
            </div>
            <div class="metric-box">
                <h3>Active Devices (7 days)</h3>
                <div class="value">$($reportData.DeviceSummary.ActiveDevices)</div>
            </div>
            <div class="metric-box">
                <h3>Compliant Devices</h3>
                <div class="value">$($reportData.DeviceSummary.CompliantDevices)</div>
            </div>
            <div class="metric-box">
                <h3>Encrypted Devices</h3>
                <div class="value">$($reportData.SecuritySummary.EncryptedDevices)</div>
            </div>
"@
            
            # Generate device overview
            $deviceOverviewHtml = "<h3>OS Distribution</h3><table>"
            $deviceOverviewHtml += "<tr><th>Operating System</th><th>Count</th></tr>"
            foreach ($os in $reportData.OSDistribution) {
                $deviceOverviewHtml += "<tr><td>$($os.Name)</td><td>$($os.Count)</td></tr>"
            }
            $deviceOverviewHtml += "</table>"
            
            # Generate security status
            $securityStatusHtml = "<table>"
            $securityStatusHtml += "<tr><th>Metric</th><th>Status</th></tr>"
            $securityStatusHtml += "<tr><td>Encrypted Devices</td><td>$($reportData.SecuritySummary.EncryptedDevices) / $($reportData.DeviceSummary.TotalDevices)</td></tr>"
            $securityStatusHtml += "<tr><td>Supervised Devices</td><td>$($reportData.SecuritySummary.SupervisedDevices) / $($reportData.DeviceSummary.TotalDevices)</td></tr>"
            $securityStatusHtml += "<tr><td>Jailbroken Devices</td><td>$($reportData.SecuritySummary.JailBrokenDevices)</td></tr>"
            $securityStatusHtml += "</table>"
            
            # Generate alerts section
            $alertsHtml = ""
            foreach ($alert in $alerts) {
                $alertsHtml += @"
                <div class="alert-box $($alert.Severity.ToLower())">
                    <strong>[$($alert.Category)] $($alert.Message)</strong>
                    <p>Affected devices: $($alert.AffectedDevices -join ', ')</p>
                </div>
"@
            }
            
            # Generate recommendations
            $recommendationsHtml = "<ul>"
            if ($reportData.DeviceSummary.NonCompliantDevices -gt 0) {
                $recommendationsHtml += "<li>Review and remediate $($reportData.DeviceSummary.NonCompliantDevices) non-compliant devices</li>"
            }
            if ($reportData.SecuritySummary.JailBrokenDevices -gt 0) {
                $recommendationsHtml += "<li>Investigate and address $($reportData.SecuritySummary.JailBrokenDevices) jailbroken devices</li>"
            }
            foreach ($app in $failedApps) {
                $recommendationsHtml += "<li>Troubleshoot failed installations of $($app.DisplayName)</li>"
            }
            $recommendationsHtml += "</ul>"
            
            # Replace template placeholders
            $report = $template
            $report = $report.Replace('{{GeneratedDate}}', $reportData.GeneratedDate)
            $report = $report.Replace('{{ExecutiveSummary}}', $executiveSummaryHtml)
            $report = $report.Replace('{{DeviceOverview}}', $deviceOverviewHtml)
            $report = $report.Replace('{{SecurityStatus}}', $securityStatusHtml)
            $report = $report.Replace('{{CriticalAlerts}}', $alertsHtml)
            $report = $report.Replace('{{Recommendations}}', $recommendationsHtml)
            
            # Save the report
            $report | Out-File -FilePath $OutputPath -Encoding UTF8
        }
        else {
            # Create CSV report
            $csvData = foreach ($device in $devices) {
                $appStatus = $appDeployments | Where-Object { $_.DeviceStatus.DeviceName -eq $device.DeviceName }
                $baselineStatus = $securityBaselines | Where-Object { $_.DeviceStates.DeviceName -eq $device.DeviceName }
                
                [PSCustomObject]@{
                    DeviceName = $device.DeviceName
                    SerialNumber = $device.SerialNumber
                    OS = $device.OperatingSystem
                    OSVersion = $device.OsVersion
                    LastSyncDateTime = $device.LastSyncDateTime
                    ComplianceState = $device.ComplianceState
                    OwnerType = $device.ManagedDeviceOwnerType
                    IsEncrypted = $device.IsEncrypted
                    IsSupervised = $device.IsSupervised
                    JailBroken = $device.JailBroken
                    AppInstallsFailed = ($appStatus | Where-Object { $_.InstallState -eq 'failed' }).Count
                    SecurityBaselinesNonCompliant = ($baselineStatus | Where-Object { $_.ComplianceState -eq 'noncompliant' }).Count
                }
            }
            
            $csvData | Export-Csv -Path $OutputPath -NoTypeInformation
        }
        
        Write-M365Log "Device management report generated successfully at: $OutputPath"
        return $OutputPath
    }
    catch {
        Write-M365Log "Error generating device management report: $_" -Level Error
        throw $_
    }
}

function Set-MK365DeviceGroupAssignment {
    <#
    .SYNOPSIS
    Manages device group assignments in Microsoft Intune.

    .DESCRIPTION
    The Set-MK365DeviceGroupAssignment function enables bulk management of device group assignments.
    It supports adding and removing devices from Azure AD groups based on various criteria such as
    device properties, compliance state, or ownership type.

    .PARAMETER DeviceFilter
    Optional. Filter devices by name, serial number, or user principal name. Supports wildcards.

    .PARAMETER GroupId
    The ID of the Azure AD group to manage assignments for.

    .PARAMETER GroupName
    The display name of the Azure AD group to manage assignments for. Either GroupId or GroupName must be specified.

    .PARAMETER Action
    The action to perform. Valid values are 'Add' or 'Remove'.

    .PARAMETER ComplianceState
    Optional. Filter devices by compliance state. Valid values are 'Compliant', 'NonCompliant', or 'Unknown'.

    .PARAMETER OwnerType
    Optional. Filter devices by ownership type. Valid values are 'Company', 'Personal'.

    .PARAMETER OSType
    Optional. Filter devices by operating system. Valid values are 'Windows', 'iOS', 'Android', 'macOS'.

    .PARAMETER WhatIf
    Switch parameter. When specified, shows what changes would occur without making them.

    .EXAMPLE
    Set-MK365DeviceGroupAssignment -GroupName "Windows Devices" -Action Add -OSType Windows
    Adds all Windows devices to the specified group.

    .EXAMPLE
    Set-MK365DeviceGroupAssignment -GroupId "12345-67890" -Action Remove -ComplianceState NonCompliant
    Removes all non-compliant devices from the specified group.

    .EXAMPLE
    Set-MK365DeviceGroupAssignment -GroupName "Corporate Devices" -Action Add -DeviceFilter "LAP-*" -OwnerType Company -WhatIf
    Shows what devices would be added to the group without making changes.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementManagedDevices.ReadWrite.All
    - Group.ReadWrite.All
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [string]$GroupId,
        
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$GroupName,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Add', 'Remove')]
        [string]$Action,
        
        [Parameter()]
        [ValidateSet('Compliant', 'NonCompliant', 'Unknown')]
        [string]$ComplianceState,
        
        [Parameter()]
        [ValidateSet('Company', 'Personal')]
        [string]$OwnerType,
        
        [Parameter()]
        [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
        [string]$OSType
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Starting device group assignment management..."
        
        # Resolve group if name is provided
        if ($GroupName) {
            Write-M365Log "Resolving group by name: $GroupName"
            $group = Get-MgGroup -Filter "displayName eq '$GroupName'"
            if (-not $group) {
                throw "Group not found: $GroupName"
            }
            $GroupId = $group.Id
        }
        
        # Get current group members
        $currentMembers = Get-MgGroupMember -GroupId $GroupId
        
        # Get devices based on filters
        $devices = Get-MgDeviceManagementManagedDevice -All
        
        # Apply filters
        if ($DeviceFilter) {
            $devices = $devices | Where-Object {
                $_.DeviceName -like "*$DeviceFilter*" -or
                $_.SerialNumber -like "*$DeviceFilter*" -or
                $_.UserPrincipalName -like "*$DeviceFilter*"
            }
        }
        
        if ($ComplianceState) {
            $devices = $devices | Where-Object { $_.ComplianceState -eq $ComplianceState }
        }
        
        if ($OwnerType) {
            $devices = $devices | Where-Object { $_.ManagedDeviceOwnerType -eq $OwnerType }
        }
        
        if ($OSType) {
            $osFilter = switch ($OSType) {
                'Windows' { 'Windows' }
                'iOS' { 'iOS' }
                'Android' { 'Android' }
                'macOS' { 'macOS' }
            }
            $devices = $devices | Where-Object { $_.OperatingSystem -like "*$osFilter*" }
        }
        
        # Process device assignments
        $processedCount = 0
        $errorCount = 0
        
        foreach ($device in $devices) {
            $deviceAzureADId = $device.AzureADDeviceId
            $isCurrentMember = $currentMembers.Id -contains $deviceAzureADId
            
            if ($Action -eq 'Add' -and -not $isCurrentMember) {
                if ($PSCmdlet.ShouldProcess($device.DeviceName, "Add to group $GroupId")) {
                    try {
                        # Create the proper reference format for the group member
                        $params = @{
                            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$deviceAzureADId"
                        }
                        
                        # Add device to group using Microsoft Graph cmdlet with correct parameters
                        New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $params
                        Write-M365Log "Added device '$($device.DeviceName)' to group"
                        $processedCount++
                    }
                    catch {
                        Write-M365Log "Failed to add device '$($device.DeviceName)' to group: $_" -Level Warning
                        $errorCount++
                    }
                }
            }
            elseif ($Action -eq 'Remove' -and $isCurrentMember) {
                if ($PSCmdlet.ShouldProcess($device.DeviceName, "Remove from group $GroupId")) {
                    try {
                        # Remove device from group using Microsoft Graph cmdlet
                        Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $deviceAzureADId
                        Write-M365Log "Removed device '$($device.DeviceName)' from group"
                        $processedCount++
                    }
                    catch {
                        Write-M365Log "Failed to remove device '$($device.DeviceName)' from group: $_" -Level Warning
                        $errorCount++
                    }
                }
            }
        }
        
        # Generate summary
        $result = [PSCustomObject]@{
            Action = $Action
            GroupId = $GroupId
            GroupName = $GroupName
            TotalDevicesProcessed = $devices.Count
            SuccessfulOperations = $processedCount
            FailedOperations = $errorCount
            Filters = @{
                DeviceFilter = $DeviceFilter
                ComplianceState = $ComplianceState
                OwnerType = $OwnerType
                OSType = $OSType
            }
        }
        
        Write-M365Log "Device group assignment management completed. Processed: $processedCount, Errors: $errorCount"
        return $result
    }
    catch {
        Write-M365Log "Error managing device group assignments: $_" -Level Error
        throw $_
    }
}

function Get-MK365SecurityStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [ValidateSet('All', 'Compliant', 'NonCompliant', 'Error')]
        [string]$ComplianceStatus = 'All',
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        Write-M365Log "Retrieving device security status..."
        
        # Get compliance policies and their states
        $policies = Get-MgDeviceManagementDeviceCompliancePolicy
        $securityStatus = @()
        
        foreach ($policy in $policies) {
            $deviceStates = Get-MgDeviceManagementDeviceCompliancePolicyDeviceStatus -DeviceCompliancePolicyId $policy.Id
            
            if ($ComplianceStatus -ne 'All') {
                $deviceStates = $deviceStates | Where-Object { $_.Status -eq $ComplianceStatus }
            }
            
            foreach ($state in $deviceStates) {
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $state.DeviceId
                
                if ($DeviceFilter -and -not ($device.DeviceName -like "*$DeviceFilter*" -or 
                    $device.SerialNumber -like "*$DeviceFilter*" -or 
                    $device.UserPrincipalName -like "*$DeviceFilter*")) {
                    continue
                }
                
                $securityStatus += [PSCustomObject]@{
                    DeviceName = $device.DeviceName
                    DeviceId = $device.Id
                    UserPrincipalName = $device.UserPrincipalName
                    PolicyName = $policy.DisplayName
                    ComplianceStatus = $state.Status
                    LastSyncDateTime = $state.LastReportedDateTime
                    OS = $device.OperatingSystem
                    OSVersion = $device.OsVersion
                    JailBroken = $device.JailBroken
                    ManagedBy = $device.ManagedDeviceOwnerType
                    Supervised = $device.IsSupervised
                    Encrypted = $device.IsEncrypted
                    ComplianceGracePeriodExpirationDateTime = $state.ComplianceGracePeriodExpirationDateTime
                    UserName = $device.UserDisplayName
                }
            }
        }
        
        # Get security baseline states
        $baselines = Get-MgDeviceManagementSecurityBaseline
        foreach ($baseline in $baselines) {
            $deviceStates = Get-MgDeviceManagementSecurityBaselineDeviceState -SecurityBaselineId $baseline.Id
            
            foreach ($state in $deviceStates) {
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $state.DeviceId
                
                if ($DeviceFilter -and -not ($device.DeviceName -like "*$DeviceFilter*" -or 
                    $device.SerialNumber -like "*$DeviceFilter*" -or 
                    $device.UserPrincipalName -like "*$DeviceFilter*")) {
                    continue
                }
                
                $securityStatus += [PSCustomObject]@{
                    DeviceName = $device.DeviceName
                    DeviceId = $device.Id
                    UserPrincipalName = $device.UserPrincipalName
                    PolicyName = "Baseline: $($baseline.DisplayName)"
                    ComplianceStatus = $state.Status
                    LastSyncDateTime = $state.LastSyncDateTime
                    OS = $device.OperatingSystem
                    OSVersion = $device.OsVersion
                    JailBroken = $device.JailBroken
                    ManagedBy = $device.ManagedDeviceOwnerType
                    Supervised = $device.IsSupervised
                    Encrypted = $device.IsEncrypted
                    ErrorCount = $state.ErrorCount
                    ConflictCount = $state.ConflictCount
                    UserName = $device.UserDisplayName
                }
            }
        }
        
        # Generate summary
        $summary = @{
            TotalDevices = ($securityStatus | Select-Object DeviceId -Unique).Count
            ComplianceBreakdown = $securityStatus | Group-Object ComplianceStatus | ForEach-Object {
                @{ Status = $_.Name; Count = $_.Count }
            }
            OSBreakdown = $securityStatus | Select-Object DeviceId, OS -Unique | Group-Object OS | ForEach-Object {
                @{ OS = $_.Name; Count = $_.Count }
            }
        }
        
        Write-M365Log "Security Status Summary:"
        Write-M365Log "Total Devices: $($summary.TotalDevices)"
        Write-M365Log "Compliance Status:"
        $summary.ComplianceBreakdown | ForEach-Object {
            Write-M365Log "  $($_.Status): $($_.Count)"
        }
        
        if ($ExportReport) {
            $reportPath = Join-Path -Path (Get-Location) -ChildPath "SecurityStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $securityStatus | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Report exported to: $reportPath"
        }
        
        return [PSCustomObject]@{
            Summary = $summary
            Details = $securityStatus
        }
    }
    catch {
        Write-M365Log "Error retrieving security status: $_" -Level Error
        throw $_
    }
}

function Get-MK365UpdateCompliance {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [ValidateSet('All', 'Pending', 'Failed', 'Success')]
        [string]$Status = 'All',
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        Write-M365Log "Retrieving update compliance status..."
        
        # Get update configurations
        $updateConfigs = Get-MgDeviceManagementDeviceConfiguration | Where-Object {
            $_.'@odata.type' -like "*update*" -or $_.'@odata.type' -like "*windowsFeatureUpdate*"
        }
        
        $updateStatus = foreach ($config in $updateConfigs) {
            $deviceStates = Get-MgDeviceManagementDeviceConfigurationDeviceStatus -DeviceConfigurationId $config.Id
            
            if ($Status -ne 'All') {
                $deviceStates = $deviceStates | Where-Object { $_.Status -eq $Status }
            }
            
            foreach ($state in $deviceStates) {
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $state.DeviceId
                
                if ($DeviceFilter -and -not ($device.DeviceName -like "*$DeviceFilter*" -or 
                    $device.SerialNumber -like "*$DeviceFilter*" -or 
                    $device.UserPrincipalName -like "*$DeviceFilter*")) {
                    continue
                }
                
                [PSCustomObject]@{
                    DeviceName = $device.DeviceName
                    DeviceId = $device.Id
                    UserPrincipalName = $device.UserPrincipalName
                    ConfigurationName = $config.DisplayName
                    Status = $state.Status
                    LastSyncDateTime = $state.LastReportedDateTime
                    OS = $device.OperatingSystem
                    OSVersion = $device.OsVersion
                    UserName = $device.UserDisplayName
                    ErrorCode = $state.ErrorCode
                    ErrorDescription = if ($state.ErrorCode) {
                        Get-MK365ErrorDescription -ErrorCode $state.ErrorCode -ErrorType 'Update'
                    } else { $null }
                }
            }
        }
        
        # Generate summary
        $summary = @{
            TotalDevices = ($updateStatus | Select-Object DeviceId -Unique).Count
            StatusBreakdown = $updateStatus | Group-Object Status | ForEach-Object {
                @{ Status = $_.Name; Count = $_.Count }
            }
            ConfigBreakdown = $updateStatus | Group-Object ConfigurationName | ForEach-Object {
                @{ Config = $_.Name; Count = $_.Count }
            }
        }
        
        Write-M365Log "Update Compliance Summary:"
        Write-M365Log "Total Devices: $($summary.TotalDevices)"
        Write-M365Log "Status Breakdown:"
        $summary.StatusBreakdown | ForEach-Object {
            Write-M365Log "  $($_.Status): $($_.Count)"
        }
        
        if ($ExportReport) {
            $reportPath = Join-Path -Path (Get-Location) -ChildPath "UpdateCompliance_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $updateStatus | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Report exported to: $reportPath"
        }
        
        return [PSCustomObject]@{
            Summary = $summary
            Details = $updateStatus
        }
    }
    catch {
        Write-M365Log "Error retrieving update compliance: $_" -Level Error
        throw $_
    }
}

function Get-MK365SystemStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'ServiceIssue', 'Advisory', 'Incident', 'Maintenance')]
        [string]$IssueType = 'All',
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        Write-M365Log "Retrieving system status..."
        
        # Get service health issues
        $healthIssues = Get-MgServiceHealth
        if ($IssueType -ne 'All') {
            $healthIssues = $healthIssues | Where-Object { $_.Classification -eq $IssueType }
        }
        
        $systemStatus = foreach ($issue in $healthIssues) {
            [PSCustomObject]@{
                Id = $issue.Id
                Title = $issue.Title
                Classification = $issue.Classification
                Status = $issue.Status
                Service = $issue.Service
                FeatureGroup = $issue.FeatureGroup
                StartDateTime = $issue.StartDateTime
                LastModifiedDateTime = $issue.LastModifiedDateTime
                Posts = $issue.Posts | ForEach-Object {
                    @{
                        CreatedDateTime = $_.CreatedDateTime
                        Description = $_.Description
                        PostType = $_.PostType
                    }
                }
                ImpactDescription = $issue.ImpactDescription
                IsResolved = $issue.Status -eq 'Resolved'
            }
        }
        
        # Generate summary
        $summary = @{
            TotalIssues = $healthIssues.Count
            ActiveIssues = ($systemStatus | Where-Object { -not $_.IsResolved }).Count
            ResolvedIssues = ($systemStatus | Where-Object { $_.IsResolved }).Count
            IssuesByType = $systemStatus | Group-Object Classification | ForEach-Object {
                @{
                    Type = $_.Name
                    Count = $_.Count
                }
            }
            IssuesByService = $systemStatus | Group-Object Service | ForEach-Object {
                @{
                    Service = $_.Name
                    Count = $_.Count
                }
            }
        }
        
        Write-M365Log "System Status Summary:"
        Write-M365Log "Total Issues: $($summary.TotalIssues)"
        Write-M365Log "Active Issues: $($summary.ActiveIssues)"
        Write-M365Log "Resolved Issues: $($summary.ResolvedIssues)"
        Write-M365Log "Issues by Type:"
        $summary.IssuesByType | ForEach-Object {
            Write-M365Log "  $($_.Type): $($_.Count)"
        }
        
        if ($ExportReport) {
            $reportPath = Join-Path -Path (Get-Location) -ChildPath "SystemStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $systemStatus | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Report exported to: $reportPath"
        }
        
        return [PSCustomObject]@{
            Summary = $summary
            Details = $systemStatus
        }
    }
    catch {
        Write-M365Log "Error retrieving system status: $_" -Level Error
        throw $_
    }
}

function Get-MK365ErrorDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorCode,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('AppInstall', 'Update', 'Compliance', 'Configuration')]
        [string]$ErrorType
    )
    
    try {
        # Get error catalog from Microsoft Graph
        $errorInfo = Get-MgDeviceManagementTroubleshootingEvent -Filter "code eq '$ErrorCode'"
        
        if ($errorInfo) {
            return $errorInfo.TroubleshootingDescription
        }
        
        # Fallback to common error codes if not found in Graph
        $commonErrors = @{
            'AppInstall' = @{
                '0x87D13B0F' = 'Insufficient disk space'
                '0x87D1041C' = 'App installation failed'
                '0x87D13B10' = 'Device not compliant'
            }
            'Update' = @{
                '0x80240022' = 'Update download failed'
                '0x80240020' = 'Update installation failed'
                '0x80240034' = 'Update not applicable'
            }
            'Compliance' = @{
                '0x87D1B258' = 'Device not compliant with security policies'
                '0x87D1B259' = 'Required application not installed'
                '0x87D1B260' = 'Security settings not configured'
            }
            'Configuration' = @{
                '0x87D13B01' = 'Configuration failed to apply'
                '0x87D13B02' = 'Invalid configuration settings'
                '0x87D13B03' = 'Device not supported'
            }
        }
        
        if ($commonErrors[$ErrorType].ContainsKey($ErrorCode)) {
            return $commonErrors[$ErrorType][$ErrorCode]
        }
        
        return "Unknown error code: $ErrorCode"
    }
    catch {
        Write-M365Log "Error retrieving error description: $_" -Level Error
        return "Error retrieving description for code: $ErrorCode"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Connect-MK365Device',
    'Disconnect-MK365Device',
    'Get-MK365DeviceOverview',
    'Export-MK365AutopilotDevices',
    'Register-MK365AutopilotDevices',
    'Get-MK365DeviceCompliance',
    'Get-MK365AppDeploymentStatus',
    'Get-MK365SecurityBaseline',
    'Export-MK365DeviceReport',
    'Set-MK365DeviceGroupAssignment',
    'Get-MK365SecurityStatus',
    'Get-MK365UpdateCompliance',
    'Get-MK365SystemStatus'
)
