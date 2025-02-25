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
                throw "Not connected to Microsoft Graph. Please connect using Connect-MK365Device first."
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
            # Get all managed devices
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

            # Enhance device information
            $enhancedDevices = foreach ($device in $devices) {
                # Get Azure AD device information
                $azureDevice = Get-MgDevice -Filter "DeviceId eq '$($device.AzureAdDeviceId)'" -ErrorAction SilentlyContinue

                # Get user information
                $user = $null
                if ($device.UserId) {
                    $user = Get-MgUser -UserId $device.UserId -ErrorAction SilentlyContinue
                }

                # Create custom object with enhanced information
                [PSCustomObject]@{
                    SerialNumber = $device.SerialNumber
                    UserName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Title = $user.JobTitle
                    School = $device.ManagedDeviceName.Split('-')[0] # Assuming school code is part of device name
                    Class = $null # To be populated from group membership
                    Model = $device.Model
                    IntuneDeviceId = $device.Id
                    AzureADDeviceId = $device.AzureAdDeviceId
                    AzureADObjectId = $azureDevice.Id
                    LastSyncDateTime = $device.LastSyncDateTime
                    OSVersion = $device.OSVersion
                    StorageTotal = [math]::Round($device.TotalStorageSpaceInBytes / 1GB, 2)
                    StorageFree = [math]::Round($device.FreeStorageSpaceInBytes / 1GB, 2)
                    ComplianceState = $device.ComplianceState
                    ManagementState = $device.ManagementState
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
