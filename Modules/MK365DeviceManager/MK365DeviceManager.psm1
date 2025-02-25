# MK365DeviceManager.psm1
# Module for managing Intune and Autopilot devices

# Import required modules
#Requires -Modules Microsoft.Graph.Intune, Microsoft.Graph.DeviceManagement

function Write-M365Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
}

function Connect-MK365Device {
    [CmdletBinding()]
    param()
    
    try {
        # Check if already connected
        if (-not (Get-MgContext)) {
            Write-M365Log "Connecting to Microsoft Graph..."
            Connect-MgGraph -Scopes @(
                "DeviceManagementManagedDevices.Read.All",
                "DeviceManagementConfiguration.ReadWrite.All",
                "DeviceManagementServiceConfig.ReadWrite.All",
                "SecurityEvents.Read.All",
                "DeviceManagementConfiguration.Read.All",
                "Group.ReadWrite.All"  # For device group assignments
            )
        }
        
        # Ensure required modules are available
        $requiredModules = @('Microsoft.Graph.Intune', 'Microsoft.Graph.DeviceManagement')
        foreach ($module in $requiredModules) {
            if (-not (Get-Module -Name $module -ListAvailable)) {
                Write-M365Log "Installing required module: $module" -Level Warning
                Install-Module -Name $module -Force -AllowClobber
            }
            Import-Module -Name $module -Force
        }
        
        Write-M365Log "Successfully connected to Microsoft Graph for device management"
    }
    catch {
        Write-M365Log "Error connecting to Microsoft Graph: $_" -Level Error
        throw $_
    }
}

function Get-MK365DeviceOverview {
    <#
    .SYNOPSIS
    Retrieves an overview of all managed devices in Intune.

    .DESCRIPTION
    The Get-MK365DeviceOverview function provides a comprehensive overview of managed devices,
    including device counts by OS, ownership type, compliance state, and management status.
    Can export results in both CSV and HTML formats.

    .PARAMETER ExportReport
    Switch parameter. When specified, exports the device overview to a report file.

    .PARAMETER ReportFormat
    Optional. Specifies the report format. Valid values are 'CSV', 'HTML', or 'Both'.
    Default is 'CSV'.

    .PARAMETER OutputPath
    Optional. Specifies the output directory for the report files.
    Default is the current directory.

    .EXAMPLE
    Get-MK365DeviceOverview
    Returns device overview as PowerShell objects.

    .EXAMPLE
    Get-MK365DeviceOverview -ExportReport -ReportFormat HTML
    Generates an HTML report of the device overview.

    .EXAMPLE
    Get-MK365DeviceOverview -ExportReport -ReportFormat Both -OutputPath "C:\Reports"
    Generates both CSV and HTML reports in the specified directory.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementManagedDevices.Read.All
    #>
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
        
        # Get all devices
        $devices = Get-MgDeviceManagementManagedDevice -All
        
        # Create overview object
        $overview = @{
            TotalDevices = $devices.Count
            LastUpdated = Get-Date
            
            OperatingSystem = $devices | Group-Object -Property OperatingSystem | Select-Object @{
                Name = 'OS'; Expression = { $_.Name }
            }, @{
                Name = 'Count'; Expression = { $_.Count }
            }
            
            OwnershipType = $devices | Group-Object -Property ManagedDeviceOwnerType | Select-Object @{
                Name = 'Type'; Expression = { $_.Name }
            }, @{
                Name = 'Count'; Expression = { $_.Count }
            }
            
            ComplianceState = $devices | Group-Object -Property ComplianceState | Select-Object @{
                Name = 'State'; Expression = { $_.Name }
            }, @{
                Name = 'Count'; Expression = { $_.Count }
            }
            
            ManagementState = $devices | Group-Object -Property ManagementState | Select-Object @{
                Name = 'State'; Expression = { $_.Name }
            }, @{
                Name = 'Count'; Expression = { $_.Count }
            }
            
            DeviceDetails = $devices | Select-Object @{
                Name = 'DeviceName'; Expression = { $_.DeviceName }
            }, @{
                Name = 'OS'; Expression = { $_.OperatingSystem }
            }, @{
                Name = 'OSVersion'; Expression = { $_.OSVersion }
            }, @{
                Name = 'Owner'; Expression = { $_.ManagedDeviceOwnerType }
            }, @{
                Name = 'Compliance'; Expression = { $_.ComplianceState }
            }, @{
                Name = 'LastSync'; Expression = { $_.LastSyncDateTime }
            }
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
                
                # Create HTML report
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
    </style>
</head>
<body>
    <h1>Device Overview Report</h1>
    <p>Generated: $($overview.LastUpdated)</p>
    <p>Total Devices: $($overview.TotalDevices)</p>

    <div class="summary">
        <h2>Operating System Distribution</h2>
        <table>
            <tr><th>Operating System</th><th>Count</th></tr>
            $(($overview.OperatingSystem | ForEach-Object { "<tr><td>$($_.OS)</td><td>$($_.Count)</td></tr>" }) -join "`n")
        </table>
    </div>

    <div class="summary">
        <h2>Ownership Type Distribution</h2>
        <table>
            <tr><th>Type</th><th>Count</th></tr>
            $(($overview.OwnershipType | ForEach-Object { "<tr><td>$($_.Type)</td><td>$($_.Count)</td></tr>" }) -join "`n")
        </table>
    </div>

    <div class="summary">
        <h2>Compliance State</h2>
        <table>
            <tr><th>State</th><th>Count</th></tr>
            $(($overview.ComplianceState | ForEach-Object { "<tr><td>$($_.State)</td><td>$($_.Count)</td></tr>" }) -join "`n")
        </table>
    </div>

    <div class="summary">
        <h2>Management State</h2>
        <table>
            <tr><th>State</th><th>Count</th></tr>
            $(($overview.ManagementState | ForEach-Object { "<tr><td>$($_.State)</td><td>$($_.Count)</td></tr>" }) -join "`n")
        </table>
    </div>

    <div class="details">
        <h2>Device Details</h2>
        <table>
            <tr>
                <th>Device Name</th>
                <th>OS</th>
                <th>OS Version</th>
                <th>Owner</th>
                <th>Compliance</th>
                <th>Last Sync</th>
            </tr>
            $(($overview.DeviceDetails | ForEach-Object {
                "<tr>
                    <td>$($_.DeviceName)</td>
                    <td>$($_.OS)</td>
                    <td>$($_.OSVersion)</td>
                    <td>$($_.Owner)</td>
                    <td>$($_.Compliance)</td>
                    <td>$($_.LastSync)</td>
                </tr>"
            }) -join "`n")
        </table>
    </div>
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
        [string]$CsvPath,
        
        [Parameter()]
        [string]$GroupTag,
        
        [Parameter()]
        [switch]$AssignUser
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Importing devices from CSV: $CsvPath"
        $devices = Import-Csv -Path $CsvPath
        
        $results = @{
            Successful = @()
            Failed = @()
        }
        
        foreach ($device in $devices) {
            try {
                $params = @{
                    SerialNumber = $device.SerialNumber
                    Manufacturer = $device.Manufacturer
                    Model = $device.Model
                }
                
                if ($GroupTag) {
                    $params.GroupTag = $GroupTag
                }
                
                if ($AssignUser -and $device.AssignedUser) {
                    $params.AssignedUser = $device.AssignedUser
                }
                
                $newDevice = New-MgDeviceManagementWindowsAutopilotDeviceIdentity -BodyParameter $params
                $results.Successful += $device.SerialNumber
                Write-M365Log "Successfully registered device: $($device.SerialNumber)"
            }
            catch {
                $results.Failed += @{
                    SerialNumber = $device.SerialNumber
                    Error = $_.Exception.Message
                }
                Write-M365Log "Failed to register device $($device.SerialNumber): $_" -Level Error
            }
        }
        
        # Generate summary
        Write-M365Log "Registration complete. Success: $($results.Successful.Count), Failed: $($results.Failed.Count)"
        return $results
    }
    catch {
        Write-M365Log "Error during bulk device registration: $_" -Level Error
        throw $_
    }
}

function Get-MK365DeviceCompliance {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [switch]$IncludeRiskDetails,
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving device compliance information..."
        
        # Get all managed devices
        $devices = Get-MgDeviceManagementManagedDevice -All
        if ($DeviceFilter) {
            $devices = $devices | Where-Object { 
                $_.DeviceName -like $DeviceFilter -or 
                $_.SerialNumber -like $DeviceFilter -or 
                $_.UserPrincipalName -like $DeviceFilter
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
            $reportPath = Join-Path (Get-Location) "DeviceCompliance-$timestamp.csv"
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
    <#
    .SYNOPSIS
    Retrieves deployment status for Intune applications.

    .DESCRIPTION
    The Get-MK365AppDeploymentStatus function provides detailed information about the deployment status of applications in Microsoft Intune. It can track deployment assignments, installation status, and generate reports for analysis.

    .PARAMETER AppDisplayName
    Optional. Filter applications by display name. Supports wildcards.

    .PARAMETER AppType
    Optional. Filter applications by type. Valid values are: 'All', 'Win32', 'iOS', 'Android', 'WindowsMobile', 'MacOS'.
    Default value is 'All'.

    .PARAMETER IncludeDeviceStatus
    Switch parameter. When specified, includes detailed installation status for each device.

    .PARAMETER ExportReport
    Switch parameter. When specified, exports the deployment status to a CSV file.

    .EXAMPLE
    Get-MK365AppDeploymentStatus
    Retrieves deployment status for all applications.

    .EXAMPLE
    Get-MK365AppDeploymentStatus -AppDisplayName "Microsoft Teams" -IncludeDeviceStatus
    Retrieves detailed deployment status for Microsoft Teams, including per-device installation status.

    .EXAMPLE
    Get-MK365AppDeploymentStatus -AppType Win32 -ExportReport
    Retrieves deployment status for Win32 applications and exports the results to a CSV file.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementApps.Read.All
    - DeviceManagementManagedDevices.Read.All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AppDisplayName,
        
        [Parameter()]
        [ValidateSet('All', 'Win32', 'iOS', 'Android', 'WindowsMobile', 'MacOS')]
        [string]$AppType = 'All',
        
        [Parameter()]
        [switch]$IncludeDeviceStatus,
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving application deployment status..."
        
        # Get all mobile apps
        $apps = Get-MgDeviceAppManagementMobileApp -All | Where-Object {
            $AppType -eq 'All' -or $_.AdditionalProperties.'@odata.type' -like "*$AppType*"
        }
        
        if ($AppDisplayName) {
            $apps = $apps | Where-Object { $_.DisplayName -like "*$AppDisplayName*" }
        }
        
        $deploymentStatus = foreach ($app in $apps) {
            $assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $app.Id
            
            $status = @{
                AppId = $app.Id
                DisplayName = $app.DisplayName
                AppType = $app.AdditionalProperties.'@odata.type'
                Publisher = $app.Publisher
                Version = $app.Version
                Assignments = @()
                DeviceStatus = @()
                Summary = @{
                    TotalDevices = 0
                    Installed = 0
                    Failed = 0
                    Pending = 0
                }
            }
            
            foreach ($assignment in $assignments) {
                $groupId = $assignment.Target.AdditionalProperties.groupId
                $groupName = if ($groupId) {
                    (Get-MgGroup -GroupId $groupId).DisplayName
                } else {
                    "All Users/Devices"
                }
                
                $status.Assignments += @{
                    GroupName = $groupName
                    Intent = $assignment.Intent
                    FilterEnabled = $assignment.Filter -ne $null
                }
            }
            
            if ($IncludeDeviceStatus) {
                $deviceStatus = Get-MgDeviceAppManagementMobileAppInstallStatus -MobileAppId $app.Id
                foreach ($device in $deviceStatus) {
                    $deviceInfo = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $device.DeviceId
                    $status.DeviceStatus += @{
                        DeviceName = $deviceInfo.DeviceName
                        UserPrincipalName = $deviceInfo.UserPrincipalName
                        InstallState = $device.InstallState
                        InstallStateDetail = $device.InstallStateDetail
                        LastModifiedDateTime = $device.LastModifiedDateTime
                    }
                    
                    # Update summary
                    $status.Summary.TotalDevices++
                    switch ($device.InstallState) {
                        "installed" { $status.Summary.Installed++ }
                        "failed" { $status.Summary.Failed++ }
                        default { $status.Summary.Pending++ }
                    }
                }
            }
            
            [PSCustomObject]$status
        }
        
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $reportPath = Join-Path (Get-Location) "AppDeploymentStatus-$timestamp.csv"
            
            if ($IncludeDeviceStatus) {
                $flattenedStatus = foreach ($app in $deploymentStatus) {
                    foreach ($device in $app.DeviceStatus) {
                        [PSCustomObject]@{
                            AppDisplayName = $app.DisplayName
                            AppType = $app.AppType
                            Publisher = $app.Publisher
                            Version = $app.Version
                            DeviceName = $device.DeviceName
                            UserPrincipalName = $device.UserPrincipalName
                            InstallState = $device.InstallState
                            InstallStateDetail = $device.InstallStateDetail
                            LastModified = $device.LastModifiedDateTime
                        }
                    }
                }
                $flattenedStatus | Export-Csv -Path $reportPath -NoTypeInformation
            } else {
                $deploymentStatus | Select-Object DisplayName, AppType, Publisher, Version, 
                    @{N='TotalDevices';E={$_.Summary.TotalDevices}},
                    @{N='Installed';E={$_.Summary.Installed}},
                    @{N='Failed';E={$_.Summary.Failed}},
                    @{N='Pending';E={$_.Summary.Pending}} |
                    Export-Csv -Path $reportPath -NoTypeInformation
            }
            
            Write-M365Log "Deployment status report exported to: $reportPath"
        }
        
        return $deploymentStatus
    }
    catch {
        Write-M365Log "Error retrieving application deployment status: $_" -Level Error
        throw $_
    }
}

function Get-MK365SecurityBaseline {
    <#
    .SYNOPSIS
    Retrieves security baseline compliance status for Intune-managed devices.

    .DESCRIPTION
    The Get-MK365SecurityBaseline function evaluates device compliance against security baselines in Microsoft Intune.
    It provides detailed information about security settings, compliance status, and remediation recommendations.

    .PARAMETER BaselineName
    Optional. Filter results by security baseline name. Supports wildcards.

    .PARAMETER DeviceFilter
    Optional. Filter devices by name, serial number, or user principal name. Supports wildcards.

    .PARAMETER IncludeSettings
    Switch parameter. When specified, includes detailed settings for each security baseline.

    .PARAMETER ExportReport
    Switch parameter. When specified, exports the baseline compliance status to a CSV file.

    .EXAMPLE
    Get-MK365SecurityBaseline
    Retrieves compliance status for all security baselines.

    .EXAMPLE
    Get-MK365SecurityBaseline -BaselineName "Windows 10 Security" -IncludeSettings
    Retrieves detailed settings for the Windows 10 security baseline.

    .EXAMPLE
    Get-MK365SecurityBaseline -DeviceFilter "LAP-*" -ExportReport
    Retrieves baseline compliance for devices matching the pattern and exports to CSV.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementConfiguration.Read.All
    - DeviceManagementManagedDevices.Read.All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaselineName,
        
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [switch]$IncludeSettings,
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving security baseline information..."
        
        # Get all security baselines
        $baselines = Get-MgDeviceManagementSecurityBaseline -All
        if ($BaselineName) {
            $baselines = $baselines | Where-Object { $_.DisplayName -like "*$BaselineName*" }
        }
        
        $baselineStatus = foreach ($baseline in $baselines) {
            $deviceStates = Get-MgDeviceManagementSecurityBaselineDeviceState -SecurityBaselineId $baseline.Id
            
            if ($DeviceFilter) {
                $deviceStates = $deviceStates | Where-Object {
                    $deviceInfo = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $_.DeviceId
                    $deviceInfo.DeviceName -like "*$DeviceFilter*" -or
                    $deviceInfo.SerialNumber -like "*$DeviceFilter*" -or
                    $deviceInfo.UserPrincipalName -like "*$DeviceFilter*"
                }
            }
            
            $status = @{
                BaselineId = $baseline.Id
                DisplayName = $baseline.DisplayName
                Description = $baseline.Description
                CreatedDateTime = $baseline.CreatedDateTime
                LastModifiedDateTime = $baseline.LastModifiedDateTime
                DeviceStates = @()
                Settings = @()
                Summary = @{
                    TotalDevices = $deviceStates.Count
                    Compliant = ($deviceStates | Where-Object { $_.State -eq 'compliant' }).Count
                    NonCompliant = ($deviceStates | Where-Object { $_.State -eq 'noncompliant' }).Count
                    Error = ($deviceStates | Where-Object { $_.State -eq 'error' }).Count
                    Conflict = ($deviceStates | Where-Object { $_.State -eq 'conflict' }).Count
                }
            }
            
            foreach ($state in $deviceStates) {
                $deviceInfo = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $state.DeviceId
                $status.DeviceStates += @{
                    DeviceName = $deviceInfo.DeviceName
                    UserPrincipalName = $deviceInfo.UserPrincipalName
                    ComplianceState = $state.State
                    LastSyncDateTime = $state.LastSyncDateTime
                    ErrorCount = $state.ErrorCount
                }
            }
            
            if ($IncludeSettings) {
                $settings = Get-MgDeviceManagementSecurityBaselineSetting -SecurityBaselineId $baseline.Id
                foreach ($setting in $settings) {
                    $status.Settings += @{
                        SettingName = $setting.SettingName
                        SettingCategory = $setting.SettingCategory
                        CurrentValue = $setting.CurrentValue
                        RequiredValue = $setting.RequiredValue
                        ComplianceStatus = if ($setting.CurrentValue -eq $setting.RequiredValue) { 'Compliant' } else { 'NonCompliant' }
                    }
                }
            }
            
            [PSCustomObject]$status
        }
        
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $reportPath = Join-Path (Get-Location) "SecurityBaseline-$timestamp.csv"
            
            if ($IncludeSettings) {
                $flattenedStatus = foreach ($baseline in $baselineStatus) {
                    foreach ($setting in $baseline.Settings) {
                        [PSCustomObject]@{
                            BaselineName = $baseline.DisplayName
                            SettingName = $setting.SettingName
                            Category = $setting.SettingCategory
                            CurrentValue = $setting.CurrentValue
                            RequiredValue = $setting.RequiredValue
                            ComplianceStatus = $setting.ComplianceStatus
                            TotalDevices = $baseline.Summary.TotalDevices
                            CompliantDevices = $baseline.Summary.Compliant
                            NonCompliantDevices = $baseline.Summary.NonCompliant
                        }
                    }
                }
            } else {
                $flattenedStatus = $baselineStatus | Select-Object DisplayName,
                    @{N='TotalDevices';E={$_.Summary.TotalDevices}},
                    @{N='CompliantDevices';E={$_.Summary.Compliant}},
                    @{N='NonCompliantDevices';E={$_.Summary.NonCompliant}},
                    @{N='ErrorDevices';E={$_.Summary.Error}},
                    @{N='ConflictDevices';E={$_.Summary.Conflict}},
                    LastModifiedDateTime
            }
            
            $flattenedStatus | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Security baseline report exported to: $reportPath"
        }
        
        return $baselineStatus
    }
    catch {
        Write-M365Log "Error retrieving security baseline information: $_" -Level Error
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
                    OSVersion = $device.OSVersion
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
                        New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $deviceAzureADId
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
    <#
    .SYNOPSIS
    Retrieves comprehensive security status for Intune-managed devices.

    .DESCRIPTION
    The Get-MK365SecurityStatus function provides a detailed security assessment of managed devices,
    including encryption status, antivirus state, firewall configuration, security policies,
    threat detection, and risk assessment scores.

    .PARAMETER DeviceFilter
    Optional. Filter devices by name, serial number, or user principal name. Supports wildcards.

    .PARAMETER RiskLevel
    Optional. Filter devices by risk level. Valid values are 'High', 'Medium', 'Low', or 'All'.
    Default is 'All'.

    .PARAMETER IncludeInactiveDevices
    Switch parameter. When specified, includes devices that haven't checked in for more than 30 days.

    .PARAMETER ExportReport
    Switch parameter. When specified, exports the security status to a CSV file.

    .EXAMPLE
    Get-MK365SecurityStatus
    Retrieves security status for all active devices.

    .EXAMPLE
    Get-MK365SecurityStatus -RiskLevel High -ExportReport
    Retrieves and exports security status for high-risk devices.

    .EXAMPLE
    Get-MK365SecurityStatus -DeviceFilter "LAP-*" -IncludeInactiveDevices
    Retrieves security status for specific devices, including inactive ones.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementManagedDevices.Read.All
    - DeviceManagementConfiguration.Read.All
    - SecurityEvents.Read.All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [ValidateSet('High', 'Medium', 'Low', 'All')]
        [string]$RiskLevel = 'All',
        
        [Parameter()]
        [switch]$IncludeInactiveDevices,
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving device security status..."
        
        # Get devices based on filters
        $devices = Get-MgDeviceManagementManagedDevice -All
        if (-not $IncludeInactiveDevices) {
            $thirtyDaysAgo = (Get-Date).AddDays(-30)
            $devices = $devices | Where-Object { $_.LastSyncDateTime -gt $thirtyDaysAgo }
        }
        
        if ($DeviceFilter) {
            $devices = $devices | Where-Object {
                $_.DeviceName -like "*$DeviceFilter*" -or
                $_.SerialNumber -like "*$DeviceFilter*" -or
                $_.UserPrincipalName -like "*$DeviceFilter*"
            }
        }
        
        # Get security baselines for compliance checking
        $securityBaselines = Get-MK365SecurityBaseline
        
        # Process each device's security status
        $securityStatus = foreach ($device in $devices) {
            # Calculate risk score based on multiple factors
            $riskFactors = @()
            $riskScore = 0
            
            # Check encryption status
            if (-not $device.IsEncrypted) {
                $riskFactors += "Device not encrypted"
                $riskScore += 30
            }
            
            # Check antivirus status
            $defenderStatus = Get-MgDeviceManagementManagedDeviceWindowsDefenderState -ManagedDeviceId $device.Id
            if ($defenderStatus.RealTimeProtectionEnabled -eq $false) {
                $riskFactors += "Real-time protection disabled"
                $riskScore += 25
            }
            if ($defenderStatus.SignatureUpdateDateTime -lt (Get-Date).AddDays(-7)) {
                $riskFactors += "Antivirus signatures outdated"
                $riskScore += 15
            }
            
            # Check firewall status
            $firewallStatus = Get-MgDeviceManagementManagedDeviceWindowsFirewallState -ManagedDeviceId $device.Id
            if (-not ($firewallStatus.DomainProfileEnabled -and $firewallStatus.PrivateProfileEnabled)) {
                $riskFactors += "Firewall disabled on one or more networks"
                $riskScore += 20
            }
            
            # Check security baseline compliance
            $baselineStatus = $securityBaselines | Where-Object {
                $_.DeviceStates | Where-Object { $_.DeviceName -eq $device.DeviceName }
            }
            $nonCompliantBaselines = $baselineStatus | Where-Object {
                ($_.DeviceStates | Where-Object { $_.DeviceName -eq $device.DeviceName }).ComplianceState -eq 'noncompliant'
            }
            if ($nonCompliantBaselines) {
                $riskFactors += "Non-compliant with $($nonCompliantBaselines.Count) security baselines"
                $riskScore += (10 * $nonCompliantBaselines.Count)
            }
            
            # Check for jailbreak/root
            if ($device.JailBroken) {
                $riskFactors += "Device is jailbroken/rooted"
                $riskScore += 50
            }
            
            # Determine risk level
            $deviceRiskLevel = switch ($riskScore) {
                { $_ -ge 50 } { 'High' }
                { $_ -ge 25 } { 'Medium' }
                default { 'Low' }
            }
            
            # Filter by risk level if specified
            if ($RiskLevel -ne 'All' -and $deviceRiskLevel -ne $RiskLevel) {
                continue
            }
            
            # Create security status object
            [PSCustomObject]@{
                DeviceName = $device.DeviceName
                SerialNumber = $device.SerialNumber
                UserPrincipalName = $device.UserPrincipalName
                LastSyncDateTime = $device.LastSyncDateTime
                OSVersion = $device.OSVersion
                RiskLevel = $deviceRiskLevel
                RiskScore = $riskScore
                RiskFactors = $riskFactors -join '; '
                IsEncrypted = $device.IsEncrypted
                IsSupervised = $device.IsSupervised
                JailBroken = $device.JailBroken
                ComplianceState = $device.ComplianceState
                AntivirusStatus = @{
                    RealTimeProtection = $defenderStatus.RealTimeProtectionEnabled
                    SignatureStatus = if ($defenderStatus.SignatureUpdateDateTime -gt (Get-Date).AddDays(-7)) { 'Current' } else { 'Outdated' }
                    LastSignatureUpdate = $defenderStatus.SignatureUpdateDateTime
                }
                FirewallStatus = @{
                    DomainProfile = $firewallStatus.DomainProfileEnabled
                    PrivateProfile = $firewallStatus.PrivateProfileEnabled
                    PublicProfile = $firewallStatus.PublicProfileEnabled
                }
                SecurityBaselines = @{
                    TotalBaselines = $baselineStatus.Count
                    CompliantBaselines = ($baselineStatus | Where-Object {
                        ($_.DeviceStates | Where-Object { $_.DeviceName -eq $device.DeviceName }).ComplianceState -eq 'compliant'
                    }).Count
                    NonCompliantBaselines = $nonCompliantBaselines.Count
                }
            }
        }
        
        # Export report if requested
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $reportPath = Join-Path (Get-Location) "SecurityStatus-$timestamp.csv"
            
            $exportData = $securityStatus | Select-Object DeviceName, SerialNumber, UserPrincipalName,
                LastSyncDateTime, OSVersion, RiskLevel, RiskScore, RiskFactors, IsEncrypted,
                IsSupervised, JailBroken, ComplianceState,
                @{N='AntivirusRealTimeProtection';E={$_.AntivirusStatus.RealTimeProtection}},
                @{N='AntivirusSignatureStatus';E={$_.AntivirusStatus.SignatureStatus}},
                @{N='FirewallDomainProfile';E={$_.FirewallStatus.DomainProfile}},
                @{N='FirewallPrivateProfile';E={$_.FirewallStatus.PrivateProfile}},
                @{N='FirewallPublicProfile';E={$_.FirewallStatus.PublicProfile}},
                @{N='CompliantBaselines';E={$_.SecurityBaselines.CompliantBaselines}},
                @{N='NonCompliantBaselines';E={$_.SecurityBaselines.NonCompliantBaselines}}
            
            $exportData | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Security status report exported to: $reportPath"
        }
        
        return $securityStatus
    }
    catch {
        Write-M365Log "Error retrieving device security status: $_" -Level Error
        throw $_
    }
}

function Get-MK365UpdateCompliance {
    <#
    .SYNOPSIS
    Retrieves update compliance status for Intune-managed devices.

    .DESCRIPTION
    The Get-MK365UpdateCompliance function provides detailed information about Windows updates,
    security patches, and application updates across managed devices. It tracks update deployment
    status, identifies devices requiring updates, and monitors update installation success rates.

    .PARAMETER DeviceFilter
    Optional. Filter devices by name, serial number, or user principal name. Supports wildcards.

    .PARAMETER UpdateType
    Optional. Filter by update type. Valid values are 'All', 'Security', 'Feature', or 'Application'.
    Default is 'All'.

    .PARAMETER PendingOnly
    Switch parameter. When specified, only shows devices with pending updates.

    .PARAMETER ExportReport
    Switch parameter. When specified, exports the update compliance status to a CSV file.

    .EXAMPLE
    Get-MK365UpdateCompliance
    Retrieves update compliance status for all devices.

    .EXAMPLE
    Get-MK365UpdateCompliance -UpdateType Security -PendingOnly -ExportReport
    Retrieves and exports status of pending security updates.

    .EXAMPLE
    Get-MK365UpdateCompliance -DeviceFilter "LAP-*" -UpdateType Feature
    Retrieves feature update status for specific devices.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - DeviceManagementManagedDevices.Read.All
    - DeviceManagementConfiguration.Read.All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeviceFilter,
        
        [Parameter()]
        [ValidateSet('All', 'Security', 'Feature', 'Application')]
        [string]$UpdateType = 'All',
        
        [Parameter()]
        [switch]$PendingOnly,
        
        [Parameter()]
        [switch]$ExportReport
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving device update compliance status..."
        
        # Get devices based on filters
        $devices = Get-MgDeviceManagementManagedDevice -All
        if ($DeviceFilter) {
            $devices = $devices | Where-Object {
                $_.DeviceName -like "*$DeviceFilter*" -or
                $_.SerialNumber -like "*$DeviceFilter*" -or
                $_.UserPrincipalName -like "*$DeviceFilter*"
            }
        }
        
        # Process each device's update status
        $updateStatus = foreach ($device in $devices) {
            # Get Windows update status
            $windowsUpdates = Get-MgDeviceManagementManagedDeviceWindowsUpdateState -ManagedDeviceId $device.Id
            
            # Get update categories
            $securityUpdates = $windowsUpdates.UpdateCategories | Where-Object { $_.Name -like "*Security*" }
            $featureUpdates = $windowsUpdates.UpdateCategories | Where-Object { $_.Name -like "*Feature*" }
            
            # Calculate update statistics
            $pendingSecurityUpdates = ($securityUpdates | Where-Object { $_.ComplianceStatus -ne 'Compliant' }).Count
            $pendingFeatureUpdates = ($featureUpdates | Where-Object { $_.ComplianceStatus -ne 'Compliant' }).Count
            
            # Get application update status
            $appUpdates = Get-MgDeviceManagementManagedDeviceWindowsProtectionState -ManagedDeviceId $device.Id
            $pendingAppUpdates = if ($appUpdates.AvSignatureVersion -lt $appUpdates.AvSignatureVersionLastUpdate) { 1 } else { 0 }
            
            # Create update status object
            $deviceUpdateStatus = [PSCustomObject]@{
                DeviceName = $device.DeviceName
                SerialNumber = $device.SerialNumber
                UserPrincipalName = $device.UserPrincipalName
                LastSyncDateTime = $device.LastSyncDateTime
                OSVersion = $device.OSVersion
                WindowsUpdateStatus = @{
                    LastScanTime = $windowsUpdates.LastScanTime
                    LastUpdateTime = $windowsUpdates.LastUpdateTime
                    PendingSecurityUpdates = $pendingSecurityUpdates
                    PendingFeatureUpdates = $pendingFeatureUpdates
                    LastSuccessfulUpdateTime = $windowsUpdates.LastSuccessfulUpdateTime
                    LastUpdateResult = $windowsUpdates.LastUpdateResult
                }
                ApplicationUpdateStatus = @{
                    AvSignatureVersion = $appUpdates.AvSignatureVersion
                    AvSignatureLastUpdate = $appUpdates.AvSignatureVersionLastUpdate
                    PendingUpdates = $pendingAppUpdates
                }
                TotalPendingUpdates = $pendingSecurityUpdates + $pendingFeatureUpdates + $pendingAppUpdates
                UpdateCompliance = if (($pendingSecurityUpdates + $pendingFeatureUpdates + $pendingAppUpdates) -eq 0) { 'Compliant' } else { 'NonCompliant' }
            }
            
            # Filter based on update type
            $includeDevice = switch ($UpdateType) {
                'Security' { $pendingSecurityUpdates -gt 0 }
                'Feature' { $pendingFeatureUpdates -gt 0 }
                'Application' { $pendingAppUpdates -gt 0 }
                default { $true }
            }
            
            # Filter for pending updates if specified
            if ($PendingOnly -and $deviceUpdateStatus.TotalPendingUpdates -eq 0) {
                $includeDevice = $false
            }
            
            if ($includeDevice) {
                $deviceUpdateStatus
            }
        }
        
        # Export report if requested
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $reportPath = Join-Path (Get-Location) "UpdateStatus-$timestamp.csv"
            
            $exportData = $updateStatus | Select-Object DeviceName, SerialNumber, UserPrincipalName,
                LastSyncDateTime, OSVersion, TotalPendingUpdates, UpdateCompliance,
                @{N='PendingSecurityUpdates';E={$_.WindowsUpdateStatus.PendingSecurityUpdates}},
                @{N='PendingFeatureUpdates';E={$_.WindowsUpdateStatus.PendingFeatureUpdates}},
                @{N='LastUpdateScan';E={$_.WindowsUpdateStatus.LastScanTime}},
                @{N='LastSuccessfulUpdate';E={$_.WindowsUpdateStatus.LastSuccessfulUpdateTime}},
                @{N='LastUpdateResult';E={$_.WindowsUpdateStatus.LastUpdateResult}},
                @{N='AvSignatureVersion';E={$_.ApplicationUpdateStatus.AvSignatureVersion}},
                @{N='AvLastUpdate';E={$_.ApplicationUpdateStatus.AvSignatureLastUpdate}}
            
            $exportData | Export-Csv -Path $reportPath -NoTypeInformation
            Write-M365Log "Update compliance report exported to: $reportPath"
        }
        
        return $updateStatus
    }
    catch {
        Write-M365Log "Error retrieving device update compliance status: $_" -Level Error
        throw $_
    }
}

function Get-MK365SystemStatus {
    <#
    .SYNOPSIS
    Retrieves the current status of Microsoft 365 services and components.

    .DESCRIPTION
    The Get-MK365SystemStatus function provides comprehensive status information about
    Microsoft 365 services, including service health, incidents, advisories, and
    planned maintenance. It covers Intune, Azure AD, and related Microsoft 365 services.

    .PARAMETER ServiceFilter
    Optional. Filter specific services to monitor. Valid values are 'All', 'Intune',
    'AzureAD', 'Exchange', 'SharePoint', 'Teams', or specific service names.
    Default is 'All'.

    .PARAMETER IncludeAdvisories
    Switch parameter. When specified, includes advisory messages that might affect services.

    .PARAMETER LastDays
    Optional. Number of days of history to include. Default is 7 days.

    .PARAMETER ExportReport
    Switch parameter. When specified, exports the status report to HTML and/or CSV.

    .PARAMETER ReportFormat
    Optional. Specifies the report format. Valid values are 'CSV', 'HTML', or 'Both'.
    Default is 'HTML'.

    .PARAMETER OutputPath
    Optional. Specifies the output directory for the report files.
    Default is the current directory.

    .EXAMPLE
    Get-MK365SystemStatus
    Returns current status of all Microsoft 365 services.

    .EXAMPLE
    Get-MK365SystemStatus -ServiceFilter Intune -LastDays 30 -ExportReport
    Exports a report of Intune service status for the last 30 days.

    .EXAMPLE
    Get-MK365SystemStatus -IncludeAdvisories -ReportFormat Both
    Retrieves status including advisories and exports in both HTML and CSV formats.

    .NOTES
    Requires the following Microsoft Graph permissions:
    - ServiceHealth.Read.All
    - ServiceMessage.Read.All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ServiceFilter = 'All',
        
        [Parameter()]
        [switch]$IncludeAdvisories,
        
        [Parameter()]
        [int]$LastDays = 7,
        
        [Parameter()]
        [switch]$ExportReport,
        
        [Parameter()]
        [ValidateSet('CSV', 'HTML', 'Both')]
        [string]$ReportFormat = 'HTML',
        
        [Parameter()]
        [string]$OutputPath = (Get-Location).Path
    )
    
    try {
        Connect-MK365Device
        
        Write-M365Log "Retrieving Microsoft 365 service status..."
        
        # Get service health information
        $startDate = (Get-Date).AddDays(-$LastDays)
        $serviceHealth = Get-MgServiceAnnouncementHealthOverview
        
        # Get active incidents
        $activeIncidents = Get-MgServiceAnnouncementIssue -Filter "Status eq 'active'"
        
        # Get advisories if requested
        $advisories = if ($IncludeAdvisories) {
            Get-MgServiceAnnouncementMessage -Filter "MessageType eq 'advisory'"
        }
        
        # Filter services if specified
        $filteredHealth = if ($ServiceFilter -ne 'All') {
            $serviceHealth | Where-Object {
                $_.Service -like "*$ServiceFilter*"
            }
        } else {
            $serviceHealth
        }
        
        # Create status object
        $systemStatus = @{
            LastUpdated = Get-Date
            ServicesOverview = $filteredHealth | Select-Object @{
                Name = 'Service'; Expression = { $_.Service }
            }, @{
                Name = 'Status'; Expression = { $_.Status }
            }, @{
                Name = 'FeatureStatus'; Expression = {
                    $_.FeatureStatus | ConvertTo-Json
                }
            }
            ActiveIncidents = $activeIncidents | Select-Object @{
                Name = 'Service'; Expression = { $_.Service }
            }, @{
                Name = 'Title'; Expression = { $_.Title }
            }, @{
                Name = 'Classification'; Expression = { $_.Classification }
            }, @{
                Name = 'StartTime'; Expression = { $_.StartDateTime }
            }, @{
                Name = 'LastUpdate'; Expression = { $_.LastModifiedDateTime }
            }, @{
                Name = 'Status'; Expression = { $_.Status }
            }, @{
                Name = 'Severity'; Expression = { $_.Severity }
            }
            Advisories = if ($IncludeAdvisories) {
                $advisories | Select-Object @{
                    Name = 'Title'; Expression = { $_.Title }
                }, @{
                    Name = 'Category'; Expression = { $_.Category }
                }, @{
                    Name = 'Severity'; Expression = { $_.Severity }
                }, @{
                    Name = 'ActionRequired'; Expression = { $_.ActionRequired }
                }, @{
                    Name = 'StartTime'; Expression = { $_.StartDateTime }
                }
            }
        }
        
        # Export report if requested
        if ($ExportReport) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            
            # Export CSV if requested
            if ($ReportFormat -in 'CSV', 'Both') {
                $csvPath = Join-Path $OutputPath "SystemStatus-$timestamp.csv"
                
                # Export services overview
                $systemStatus.ServicesOverview | Export-Csv -Path $csvPath -NoTypeInformation
                Write-M365Log "Services overview exported to: $csvPath"
                
                # Export incidents
                $incidentsPath = Join-Path $OutputPath "SystemIncidents-$timestamp.csv"
                $systemStatus.ActiveIncidents | Export-Csv -Path $incidentsPath -NoTypeInformation
                Write-M365Log "Active incidents exported to: $incidentsPath"
                
                # Export advisories if included
                if ($IncludeAdvisories) {
                    $advisoriesPath = Join-Path $OutputPath "SystemAdvisories-$timestamp.csv"
                    $systemStatus.Advisories | Export-Csv -Path $advisoriesPath -NoTypeInformation
                    Write-M365Log "Advisories exported to: $advisoriesPath"
                }
            }
            
            # Export HTML if requested
            if ($ReportFormat -in 'HTML', 'Both') {
                $htmlPath = Join-Path $OutputPath "SystemStatus-$timestamp.html"
                
                # Create HTML report
                $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Microsoft 365 System Status Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #2c3e50; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f5f6fa; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .summary { margin-bottom: 30px; }
        .status-healthy { color: green; }
        .status-warning { color: orange; }
        .status-critical { color: red; }
        .status-unknown { color: gray; }
    </style>
</head>
<body>
    <h1>Microsoft 365 System Status Report</h1>
    <p>Generated: $($systemStatus.LastUpdated)</p>

    <div class="summary">
        <h2>Services Overview</h2>
        <table>
            <tr>
                <th>Service</th>
                <th>Status</th>
                <th>Feature Status</th>
            </tr>
            $(($systemStatus.ServicesOverview | ForEach-Object {
                $statusClass = switch ($_.Status) {
                    'healthy' { 'status-healthy' }
                    'warning' { 'status-warning' }
                    'critical' { 'status-critical' }
                    default { 'status-unknown' }
                }
                "<tr>
                    <td>$($_.Service)</td>
                    <td class='$statusClass'>$($_.Status)</td>
                    <td>$($_.FeatureStatus)</td>
                </tr>"
            }) -join "`n")
        </table>
    </div>

    <div class="summary">
        <h2>Active Incidents</h2>
        <table>
            <tr>
                <th>Service</th>
                <th>Title</th>
                <th>Classification</th>
                <th>Start Time</th>
                <th>Last Update</th>
                <th>Status</th>
                <th>Severity</th>
            </tr>
            $(($systemStatus.ActiveIncidents | ForEach-Object {
                "<tr>
                    <td>$($_.Service)</td>
                    <td>$($_.Title)</td>
                    <td>$($_.Classification)</td>
                    <td>$($_.StartTime)</td>
                    <td>$($_.LastUpdate)</td>
                    <td>$($_.Status)</td>
                    <td>$($_.Severity)</td>
                </tr>"
            }) -join "`n")
        </table>
    </div>

    $(if ($IncludeAdvisories) {
    @"
    <div class="summary">
        <h2>Advisories</h2>
        <table>
            <tr>
                <th>Title</th>
                <th>Category</th>
                <th>Severity</th>
                <th>Action Required</th>
                <th>Start Time</th>
            </tr>
            $(($systemStatus.Advisories | ForEach-Object {
                "<tr>
                    <td>$($_.Title)</td>
                    <td>$($_.Category)</td>
                    <td>$($_.Severity)</td>
                    <td>$($_.ActionRequired)</td>
                    <td>$($_.StartTime)</td>
                </tr>"
            }) -join "`n")
        </table>
    </div>
"@
    })
</body>
</html>
"@
                $htmlReport | Out-File -FilePath $htmlPath -Encoding UTF8
                Write-M365Log "HTML report exported to: $htmlPath"
            }
        }
        
        return $systemStatus
    }
    catch {
        Write-M365Log "Error retrieving Microsoft 365 system status: $_" -Level Error
        throw $_
    }
}

# Export functions
Export-ModuleMember -Function @(
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
    'Get-MK365UpdateCompliance',
    'Get-MK365SystemStatus'
)
