function Get-MK365DeviceInventory {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('PC', 'iPad', 'All')]
        [string]$DeviceType = 'All',

        [Parameter()]
        [string[]]$GradeLevels,

        [Parameter()]
        [string]$School,

        [Parameter()]
        [switch]$IncludeDetails,

        [Parameter()]
        [switch]$ExportReport,

        [Parameter()]
        [string]$OutputPath = "$env:USERPROFILE\Documents\DeviceReports"
    )

    begin {
        # Ensure we're connected to Microsoft Graph
        try {
            $context = Get-MgContext
            if (-not $context) {
                throw "Not connected to Microsoft Graph. Please connect using Connect-MgGraph first."
            }
        }
        catch {
            throw "Failed to verify Microsoft Graph connection: $_"
        }

        # Create output directory if it doesn't exist
        if ($ExportReport -and -not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
    }

    process {
        try {
            # Get all managed devices using latest Graph cmdlets
            Write-Verbose "Retrieving managed devices..."
            $devices = Get-MgDeviceManagementManagedDevice -All

            # Filter by device type if specified
            if ($DeviceType -ne 'All') {
                $devices = $devices | Where-Object {
                    if ($DeviceType -eq 'PC') {
                        $_.OperatingSystem -eq 'Windows'
                    } else {
                        $_.OperatingSystem -eq 'iOS'
                    }
                }
            }

            # Enhance device information using parallel processing for better performance
            $enhancedDevices = $devices | ForEach-Object -ThrottleLimit 10 -Parallel {
                # Get Azure AD device information using new cmdlets
                $azureDevice = Get-MgDevice -Filter "DeviceId eq '$($_.AzureAdDeviceId)'" -ErrorAction SilentlyContinue

                # Get user information using new cmdlets
                $user = $null
                if ($_.UserId) {
                    $user = Get-MgUser -UserId $_.UserId -ErrorAction SilentlyContinue
                }

                # Get group memberships for class information
                $groups = $null
                if ($user) {
                    $groups = Get-MgUserMemberOf -UserId $user.Id -ErrorAction SilentlyContinue
                }

                # Get detailed device configuration
                $deviceConfig = Get-MgDeviceManagementManagedDeviceConfigurationState -ManagedDeviceId $_.Id -ErrorAction SilentlyContinue

                # Create custom object with enhanced information
                [PSCustomObject]@{
                    SerialNumber = $_.SerialNumber
                    UserName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Title = $user.JobTitle
                    School = $_.ManagedDeviceName.Split('-')[0]
                    Class = ($groups | Where-Object { $_.AdditionalProperties.displayName -match '^[0-9]' }).AdditionalProperties.displayName -join ';'
                    Model = $_.Model
                    IntuneDeviceId = $_.Id
                    AzureADDeviceId = $_.AzureAdDeviceId
                    AzureADObjectId = $azureDevice.Id
                    LastSyncDateTime = $_.LastSyncDateTime
                    OSVersion = $_.OSVersion
                    StorageTotal = [math]::Round($_.TotalStorageSpaceInBytes / 1GB, 2)
                    StorageFree = [math]::Round($_.FreeStorageSpaceInBytes / 1GB, 2)
                    ComplianceState = $_.ComplianceState
                    ManagementState = $_.ManagementState
                    ConfigurationStatus = ($deviceConfig | ForEach-Object { "$($_.ConfigurationDisplayName): $($_.State)" }) -join '; '
                    LastModifiedDateTime = $_.LastModifiedDateTime
                    EnrollmentDateTime = $_.EnrollmentDateTime
                    DeviceName = $_.DeviceName
                    Manufacturer = $_.Manufacturer
                    JoinType = $_.JoinType
                    Category = $_.DeviceCategory
                }
            }

            # Filter by grade levels if specified
            if ($GradeLevels) {
                $enhancedDevices = $enhancedDevices | Where-Object {
                    foreach ($grade in $GradeLevels) {
                        if ($_.Class -match $grade) {
                            return $true
                        }
                    }
                    return $false
                }
            }

            # Filter by school if specified
            if ($School) {
                $enhancedDevices = $enhancedDevices | Where-Object { $_.School -eq $School }
            }

            # Export report if requested
            if ($ExportReport) {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $fileName = "DeviceInventory-$timestamp.csv"
                $filePath = Join-Path $OutputPath $fileName
                
                $enhancedDevices | Export-Csv -Path $filePath -NoTypeInformation -Delimiter ";"
                Write-Verbose "Report exported to: $filePath"
            }

            # Return the results
            return $enhancedDevices
        }
        catch {
            Write-Error "Failed to retrieve device inventory: $_"
        }
    }
}
