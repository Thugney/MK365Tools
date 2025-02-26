function Get-MK365DeviceInventory {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByGrade')]
        [ValidateSet('PC', 'iPad', 'All')]
        [string]$DeviceType = 'All',

        [Parameter(ParameterSetName = 'ByGrade')]
        [string[]]$GradeLevels,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByGrade')]
        [string]$School,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByGrade')]
        [switch]$IncludeDetails,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByGrade')]
        [switch]$ExportReport,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByGrade')]
        [string]$OutputPath = "$env:USERPROFILE\Documents\DeviceReports"
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
    }

    process {
        try {
            # Get all managed devices using latest Graph cmdlets
            Write-Verbose "Retrieving managed devices..."
            $devices = Get-MgDeviceManagementManagedDevice -All
            
            if (-not $devices -or $devices.Count -eq 0) {
                Write-Warning "No managed devices found"
                return @()
            }
            
            Write-Verbose "Found $($devices.Count) managed devices"
            
            # Filter by device type if specified
            if ($DeviceType -ne 'All') {
                if ($DeviceType -eq 'PC') {
                    $devices = $devices | Where-Object { $_.OperatingSystem -eq 'Windows' }
                }
                elseif ($DeviceType -eq 'iPad') {
                    $devices = $devices | Where-Object { $_.OperatingSystem -eq 'iOS' -or $_.OperatingSystem -eq 'iPadOS' }
                }
                
                Write-Verbose "Filtered to $($devices.Count) $DeviceType devices"
            }
            
            # Create custom objects with relevant properties
            $deviceInventory = $devices | ForEach-Object {
                $device = $_
                
                # Get user details if available
                $userPrincipalName = $null
                $userName = $null
                
                if ($device.UserId) {
                    try {
                        $user = Get-MgUser -UserId $device.UserId -ErrorAction SilentlyContinue
                        if ($user) {
                            $userPrincipalName = $user.UserPrincipalName
                            $userName = $user.DisplayName
                        }
                    }
                    catch {
                        Write-Verbose "Could not retrieve user details for device $($device.DeviceName): $($_.Exception.Message)"
                    }
                }
                
                # Create custom object with device properties
                [PSCustomObject]@{
                    DeviceName = $device.DeviceName
                    SerialNumber = $device.SerialNumber
                    Model = $device.Model
                    Manufacturer = $device.Manufacturer
                    OSVersion = $device.OsVersion
                    LastSyncDateTime = $device.LastSyncDateTime
                    EnrolledDateTime = $device.EnrolledDateTime
                    UserPrincipalName = $userPrincipalName
                    UserDisplayName = $userName
                    ComplianceState = $device.ComplianceState
                    ManagementState = $device.ManagementState
                    OwnerType = $device.OwnerType
                    JoinType = $device.JoinType
                    StorageTotal = [math]::Round($device.TotalStorageSpaceInBytes / 1GB, 2)
                    StorageFree = [math]::Round($device.FreeStorageSpaceInBytes / 1GB, 2)
                    IntuneDeviceId = $device.Id
                    AzureADDeviceId = $device.AzureADDeviceId
                    AzureADObjectId = $device.AzureADDeviceId
                }
            }
            
            # Filter by school if specified
            if ($School) {
                Write-Verbose "Filtering devices by school: $School"
                $deviceInventory = $deviceInventory | Where-Object {
                    # Check if device name contains school name (common naming convention)
                    $_.DeviceName -like "*$School*"
                }
                
                Write-Verbose "Found $($deviceInventory.Count) devices for school: $School"
            }
            
            # Filter by grade levels if specified
            if ($PSCmdlet.ParameterSetName -eq 'ByGrade' -and $GradeLevels) {
                Write-Verbose "Filtering devices by grade levels: $($GradeLevels -join ', ')"
                
                # This requires looking up users and their group memberships
                # We'll need to check if users are members of groups with grade level names
                $filteredDevices = @()
                
                foreach ($device in $deviceInventory) {
                    if (-not $device.UserPrincipalName) {
                        continue
                    }
                    
                    try {
                        # Get user's group memberships
                        $user = Get-MgUser -UserId $device.UserPrincipalName -ErrorAction SilentlyContinue
                        if ($user) {
                            $userGroups = Get-MgUserMemberOf -UserId $user.Id -ErrorAction SilentlyContinue
                            
                            # Check if any group names match the specified grade levels
                            $matchesGrade = $false
                            foreach ($gradeLevel in $GradeLevels) {
                                foreach ($group in $userGroups) {
                                    if ($group.AdditionalProperties.displayName -like "*$gradeLevel*") {
                                        $matchesGrade = $true
                                        break
                                    }
                                }
                                
                                if ($matchesGrade) {
                                    break
                                }
                            }
                            
                            if ($matchesGrade) {
                                $filteredDevices += $device
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Error checking grade level for device $($device.DeviceName): $($_.Exception.Message)"
                    }
                }
                
                $deviceInventory = $filteredDevices
                Write-Verbose "Found $($deviceInventory.Count) devices matching grade levels"
            }
            
            # Export report if requested
            if ($ExportReport) {
                # Create output directory if it doesn't exist
                if (-not (Test-Path -Path $OutputPath)) {
                    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
                }
                
                # Generate report filename
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $reportPath = Join-Path -Path $OutputPath -ChildPath "DeviceInventory-$timestamp.csv"
                
                # Export to CSV
                $deviceInventory | Export-Csv -Path $reportPath -NoTypeInformation
                Write-Verbose "Exported device inventory to: $reportPath"
            }
            
            return $deviceInventory
        }
        catch {
            Write-Error "Failed to retrieve device inventory: $($_.Exception.Message)"
        }
    }
}
