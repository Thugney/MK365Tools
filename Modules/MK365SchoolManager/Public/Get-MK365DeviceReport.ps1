function Get-MK365DeviceReport {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$School,
        
        [Parameter()]
        [string[]]$GradeLevels,
        
        [Parameter()]
        [ValidateSet('PC', 'iPad', 'All')]
        [string]$DeviceType = 'All',
        
        [Parameter()]
        [string[]]$Models,
        
        [Parameter()]
        [switch]$IncludeUserDetails,
        
        [Parameter()]
        [switch]$IncludeGroupDetails,
        
        [Parameter()]
        [switch]$ExportReport,
        
        [Parameter()]
        [string]$OutputPath = "$env:USERPROFILE\Documents\DeviceReports",
        
        [Parameter()]
        [string]$ReportFormat = 'CSV'
    )
    
    begin {
        # Ensure we're connected to Microsoft Graph
        try {
            $context = Get-MgContext
            if (-not $context) {
                throw "Not connected to Microsoft Graph. Please connect using Connect-MK365School first."
            }
        }
        catch {
            throw "Failed to verify Microsoft Graph connection: $($_.Exception.Message)"
        }
        
        # Create output directory if it doesn't exist and export is requested
        if ($ExportReport -and -not (Test-Path -Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created output directory: $OutputPath"
        }
    }
    
    process {
        try {
            # Get device inventory
            Write-Verbose "Retrieving device inventory..."
            $deviceParams = @{
                IncludeDetails = $true
            }
            
            if ($School) {
                $deviceParams.School = $School
            }
            
            if ($DeviceType -ne 'All') {
                $deviceParams.DeviceType = $DeviceType
            }
            
            $devices = Get-MK365DeviceInventory @deviceParams
            
            if (-not $devices -or $devices.Count -eq 0) {
                Write-Warning "No devices found matching the specified criteria"
                return @()
            }
            
            Write-Verbose "Found $($devices.Count) devices in total"
            
            # Filter by models if specified
            if ($Models) {
                $devices = $devices | Where-Object { $_.Model -in $Models }
                Write-Verbose "Filtered to $($devices.Count) devices matching specified models"
            }
            
            # Create enhanced device report objects
            $deviceReports = @()
            
            foreach ($device in $devices) {
                $deviceReport = [PSCustomObject]@{
                    SerialNumber = $device.SerialNumber
                    DeviceName = $device.DeviceName
                    Model = $device.Model
                    Manufacturer = $device.Manufacturer
                    OSVersion = $device.OSVersion
                    LastSyncDateTime = $device.LastSyncDateTime
                    EnrolledDateTime = $device.EnrolledDateTime
                    UserPrincipalName = $device.UserPrincipalName
                    UserDisplayName = $device.UserDisplayName
                    ComplianceState = $device.ComplianceState
                    ManagementState = $device.ManagementState
                    IntuneDeviceId = $device.IntuneDeviceId
                    AzureADDeviceId = $device.AzureADDeviceId
                    AzureADObjectId = $device.AzureADObjectId
                    StorageTotal = $device.StorageTotal
                    StorageFree = $device.StorageFree
                    UserDetails = $null
                    UserGroups = @()
                    GradeLevels = @()
                    School = ""
                }
                
                # Extract school from device name (common naming convention)
                if ($device.DeviceName -match '([^-]+)-') {
                    $deviceReport.School = $matches[1]
                }
                
                # Get user details if requested and user exists
                if ($IncludeUserDetails -and $device.UserPrincipalName) {
                    try {
                        $user = Get-MgUser -UserId $device.UserPrincipalName -ErrorAction SilentlyContinue
                        
                        if ($user) {
                            $deviceReport.UserDetails = [PSCustomObject]@{
                                DisplayName = $user.DisplayName
                                UserPrincipalName = $user.UserPrincipalName
                                Mail = $user.Mail
                                JobTitle = $user.JobTitle
                                Department = $user.Department
                                OfficeLocation = $user.OfficeLocation
                                MobilePhone = $user.MobilePhone
                            }
                            
                            # Get user groups if requested
                            if ($IncludeGroupDetails) {
                                try {
                                    $userGroups = Get-MgUserMemberOf -UserId $user.Id -All
                                    
                                    foreach ($group in $userGroups) {
                                        # Check if it's a group (not a role)
                                        if ($group.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group') {
                                            $groupName = $group.AdditionalProperties.displayName
                                            $deviceReport.UserGroups += $groupName
                                            
                                            # Check if group name matches any grade level patterns
                                            if ($groupName -match '(\d+)\s*\.\s*trinn' -or 
                                                $groupName -match 'klasse\s*(\d+)' -or
                                                $groupName -match 'grade\s*(\d+)') {
                                                $deviceReport.GradeLevels += $matches[0]
                                            }
                                        }
                                    }
                                }
                                catch {
                                    Write-Verbose "Could not retrieve groups for user $($user.UserPrincipalName): $($_.Exception.Message)"
                                }
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Could not retrieve details for user $($device.UserPrincipalName): $($_.Exception.Message)"
                    }
                }
                
                $deviceReports += $deviceReport
            }
            
            # Filter by grade levels if specified
            if ($GradeLevels) {
                $filteredDevices = @()
                
                foreach ($device in $deviceReports) {
                    foreach ($gradeLevel in $GradeLevels) {
                        if ($device.GradeLevels -contains $gradeLevel -or 
                            $device.UserGroups | Where-Object { $_ -like "*$gradeLevel*" }) {
                            $filteredDevices += $device
                            break
                        }
                    }
                }
                
                $deviceReports = $filteredDevices
                Write-Verbose "Filtered to $($deviceReports.Count) devices matching specified grade levels"
            }
            
            # Export report if requested
            if ($ExportReport) {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $schoolSuffix = if ($School) { "-$School" } else { "" }
                $reportPath = Join-Path -Path $OutputPath -ChildPath "DeviceReport$schoolSuffix-$timestamp"
                
                if ($ReportFormat -eq 'CSV') {
                    # Flatten the object for CSV export
                    $flatDevices = $deviceReports | ForEach-Object {
                        $device = $_
                        
                        $flatDevice = [PSCustomObject]@{
                            SerialNumber = $device.SerialNumber
                            DeviceName = $device.DeviceName
                            Model = $device.Model
                            Manufacturer = $device.Manufacturer
                            OSVersion = $device.OSVersion
                            LastSyncDateTime = $device.LastSyncDateTime
                            EnrolledDateTime = $device.EnrolledDateTime
                            UserPrincipalName = $device.UserPrincipalName
                            UserDisplayName = $device.UserDisplayName
                            UserTitle = if ($device.UserDetails) { $device.UserDetails.JobTitle } else { "" }
                            UserDepartment = if ($device.UserDetails) { $device.UserDetails.Department } else { "" }
                            UserOffice = if ($device.UserDetails) { $device.UserDetails.OfficeLocation } else { "" }
                            UserGroups = ($device.UserGroups -join ';')
                            GradeLevels = ($device.GradeLevels -join ';')
                            School = $device.School
                            ComplianceState = $device.ComplianceState
                            ManagementState = $device.ManagementState
                            IntuneDeviceId = $device.IntuneDeviceId
                            AzureADDeviceId = $device.AzureADDeviceId
                            AzureADObjectId = $device.AzureADObjectId
                            StorageTotal = $device.StorageTotal
                            StorageFree = $device.StorageFree
                        }
                        
                        return $flatDevice
                    }
                    
                    $reportPath = "$reportPath.csv"
                    $flatDevices | Export-Csv -Path $reportPath -NoTypeInformation
                }
                elseif ($ReportFormat -eq 'JSON') {
                    $reportPath = "$reportPath.json"
                    $deviceReports | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath
                }
                elseif ($ReportFormat -eq 'Excel') {
                    $reportPath = "$reportPath.xlsx"
                    
                    # Check if ImportExcel module is available
                    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                        Write-Warning "ImportExcel module is not installed. Please install it using: Install-Module ImportExcel -Scope CurrentUser"
                        Write-Warning "Falling back to CSV format"
                        
                        $reportPath = "$reportPath.csv"
                        $deviceReports | Export-Csv -Path $reportPath -NoTypeInformation
                    }
                    else {
                        # Flatten the object for Excel export
                        $flatDevices = $deviceReports | ForEach-Object {
                            $device = $_
                            
                            $flatDevice = [PSCustomObject]@{
                                SerialNumber = $device.SerialNumber
                                DeviceName = $device.DeviceName
                                Model = $device.Model
                                Manufacturer = $device.Manufacturer
                                OSVersion = $device.OSVersion
                                LastSyncDateTime = $device.LastSyncDateTime
                                EnrolledDateTime = $device.EnrolledDateTime
                                UserPrincipalName = $device.UserPrincipalName
                                UserDisplayName = $device.UserDisplayName
                                UserTitle = if ($device.UserDetails) { $device.UserDetails.JobTitle } else { "" }
                                UserDepartment = if ($device.UserDetails) { $device.UserDetails.Department } else { "" }
                                UserOffice = if ($device.UserDetails) { $device.UserDetails.OfficeLocation } else { "" }
                                UserGroups = ($device.UserGroups -join ';')
                                GradeLevels = ($device.GradeLevels -join ';')
                                School = $device.School
                                ComplianceState = $device.ComplianceState
                                ManagementState = $device.ManagementState
                                IntuneDeviceId = $device.IntuneDeviceId
                                AzureADDeviceId = $device.AzureADDeviceId
                                AzureADObjectId = $device.AzureADObjectId
                                StorageTotal = $device.StorageTotal
                                StorageFree = $device.StorageFree
                            }
                            
                            return $flatDevice
                        }
                        
                        $flatDevices | Export-Excel -Path $reportPath -AutoSize -FreezeTopRow -BoldTopRow
                    }
                }
                
                Write-Verbose "Exported device report to: $reportPath"
            }
            
            return $deviceReports
        }
        catch {
            Write-Error "Failed to generate device report: $($_.Exception.Message)"
            throw $_
        }
    }
}
