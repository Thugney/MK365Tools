function Remove-MK365RetiredDevice {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ParameterSetName = 'BySerialNumber')]
        [string[]]$SerialNumbers,
        
        [Parameter(Mandatory, ParameterSetName = 'ByDeviceId')]
        [string[]]$IntuneDeviceIds,
        
        [Parameter(Mandatory, ParameterSetName = 'ByReport')]
        [string]$CsvReportPath,
        
        [Parameter()]
        [switch]$RemoveFromAutoPilot,
        
        [Parameter()]
        [switch]$RemoveFromAzureAD,
        
        [Parameter()]
        [switch]$ExportResults,
        
        [Parameter()]
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
        
        # Check for AzureAD module if needed
        if ($RemoveFromAzureAD) {
            try {
                $azureADModule = Get-Module -Name AzureAD -ListAvailable
                if (-not $azureADModule) {
                    throw "AzureAD module is required for removing devices from Azure AD. Please install it using: Install-Module AzureAD -Scope CurrentUser"
                }
                
                # Check if connected to AzureAD
                try {
                    $azureADConnection = Get-AzureADCurrentSessionInfo -ErrorAction Stop
                }
                catch {
                    throw "Not connected to Azure AD. Please connect using Connect-AzureAD first."
                }
            }
            catch {
                throw "AzureAD module check failed: $($_.Exception.Message)"
            }
        }
        
        # Create output directory if it doesn't exist and export is requested
        if ($ExportResults -and -not (Test-Path -Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created output directory: $OutputPath"
        }
        
        # Initialize results tracking
        $results = @{
            StartTime = Get-Date
            EndTime = $null
            DevicesToRemove = @()
            IntuneRemovalResults = @{
                Successful = @()
                Failed = @()
                NotFound = @()
            }
            AutoPilotRemovalResults = @{
                Successful = @()
                Failed = @()
                NotFound = @()
            }
            AzureADRemovalResults = @{
                Successful = @()
                Failed = @()
                NotFound = @()
            }
        }
    }
    
    process {
        try {
            # Get the list of devices to remove
            $devicesToRemove = @()
            
            if ($PSCmdlet.ParameterSetName -eq 'BySerialNumber') {
                Write-Verbose "Getting devices by serial numbers..."
                
                foreach ($serialNumber in $SerialNumbers) {
                    $device = Get-MK365DeviceInventory | Where-Object { $_.SerialNumber -eq $serialNumber }
                    
                    if ($device) {
                        $devicesToRemove += $device
                    }
                    else {
                        Write-Warning "Device with serial number '$serialNumber' not found in inventory"
                        
                        # Add to results as not found
                        $notFoundDevice = [PSCustomObject]@{
                            SerialNumber = $serialNumber
                            IntuneDeviceId = $null
                            AzureADDeviceId = $null
                            AzureADObjectId = $null
                            NotFoundReason = "Serial number not found in inventory"
                        }
                        
                        $results.IntuneRemovalResults.NotFound += $notFoundDevice
                        
                        if ($RemoveFromAutoPilot) {
                            $results.AutoPilotRemovalResults.NotFound += $notFoundDevice
                        }
                        
                        if ($RemoveFromAzureAD) {
                            $results.AzureADRemovalResults.NotFound += $notFoundDevice
                        }
                    }
                }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByDeviceId') {
                Write-Verbose "Getting devices by Intune device IDs..."
                
                foreach ($deviceId in $IntuneDeviceIds) {
                    $device = Get-MK365DeviceInventory | Where-Object { $_.IntuneDeviceId -eq $deviceId }
                    
                    if ($device) {
                        $devicesToRemove += $device
                    }
                    else {
                        Write-Warning "Device with Intune ID '$deviceId' not found in inventory"
                        
                        # Add to results as not found
                        $notFoundDevice = [PSCustomObject]@{
                            SerialNumber = $null
                            IntuneDeviceId = $deviceId
                            AzureADDeviceId = $null
                            AzureADObjectId = $null
                            NotFoundReason = "Intune device ID not found in inventory"
                        }
                        
                        $results.IntuneRemovalResults.NotFound += $notFoundDevice
                        
                        if ($RemoveFromAutoPilot) {
                            $results.AutoPilotRemovalResults.NotFound += $notFoundDevice
                        }
                        
                        if ($RemoveFromAzureAD) {
                            $results.AzureADRemovalResults.NotFound += $notFoundDevice
                        }
                    }
                }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByReport') {
                Write-Verbose "Getting devices from CSV report: $CsvReportPath"
                
                if (-not (Test-Path -Path $CsvReportPath)) {
                    throw "CSV report file not found: $CsvReportPath"
                }
                
                $reportDevices = Import-Csv -Path $CsvReportPath
                
                foreach ($reportDevice in $reportDevices) {
                    # Check if the CSV has the required columns
                    if (-not $reportDevice.SerialNumber -and -not $reportDevice.IntuneDeviceId) {
                        throw "CSV report must contain either 'SerialNumber' or 'IntuneDeviceId' columns"
                    }
                    
                    $device = $null
                    
                    # Try to find by serial number first
                    if ($reportDevice.SerialNumber) {
                        $device = Get-MK365DeviceInventory | Where-Object { $_.SerialNumber -eq $reportDevice.SerialNumber }
                    }
                    
                    # If not found by serial number, try by Intune device ID
                    if (-not $device -and $reportDevice.IntuneDeviceId) {
                        $device = Get-MK365DeviceInventory | Where-Object { $_.IntuneDeviceId -eq $reportDevice.IntuneDeviceId }
                    }
                    
                    if ($device) {
                        $devicesToRemove += $device
                    }
                    else {
                        $serialNumber = $reportDevice.SerialNumber
                        $intuneDeviceId = $reportDevice.IntuneDeviceId
                        
                        Write-Warning "Device with serial number '$serialNumber' or Intune ID '$intuneDeviceId' not found in inventory"
                        
                        # Add to results as not found
                        $notFoundDevice = [PSCustomObject]@{
                            SerialNumber = $serialNumber
                            IntuneDeviceId = $intuneDeviceId
                            AzureADDeviceId = $reportDevice.AzureADDeviceId
                            AzureADObjectId = $reportDevice.AzureADObjectId
                            NotFoundReason = "Device not found in inventory"
                        }
                        
                        $results.IntuneRemovalResults.NotFound += $notFoundDevice
                        
                        if ($RemoveFromAutoPilot) {
                            $results.AutoPilotRemovalResults.NotFound += $notFoundDevice
                        }
                        
                        if ($RemoveFromAzureAD) {
                            $results.AzureADRemovalResults.NotFound += $notFoundDevice
                        }
                    }
                }
            }
            
            $devicesToRemove = $devicesToRemove | Sort-Object -Property SerialNumber -Unique
            $results.DevicesToRemove = $devicesToRemove
            
            if ($devicesToRemove.Count -eq 0) {
                Write-Warning "No devices found to remove"
                return $results
            }
            
            Write-Verbose "Found $($devicesToRemove.Count) devices to remove"
            
            # Display summary and confirm
            Write-Host "`n===== Device Removal Summary =====" -ForegroundColor Cyan
            Write-Host "Devices to remove: $($devicesToRemove.Count)" -ForegroundColor Cyan
            Write-Host "Remove from Intune: Yes" -ForegroundColor Cyan
            Write-Host "Remove from AutoPilot: $($RemoveFromAutoPilot)" -ForegroundColor Cyan
            Write-Host "Remove from Azure AD: $($RemoveFromAzureAD)" -ForegroundColor Cyan
            Write-Host "==============================`n" -ForegroundColor Cyan
            
            # Remove devices from Intune
            foreach ($device in $devicesToRemove) {
                # Remove from Intune
                if ($PSCmdlet.ShouldProcess($device.SerialNumber, "Remove from Intune")) {
                    try {
                        Write-Verbose "Removing device $($device.SerialNumber) from Intune..."
                        Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $device.IntuneDeviceId
                        $results.IntuneRemovalResults.Successful += $device
                        Write-Verbose "Successfully removed device $($device.SerialNumber) from Intune"
                    }
                    catch {
                        Write-Warning "Failed to remove device $($device.SerialNumber) from Intune: $($_.Exception.Message)"
                        $results.IntuneRemovalResults.Failed += $device
                    }
                }
                
                # Remove from AutoPilot if requested
                if ($RemoveFromAutoPilot -and $PSCmdlet.ShouldProcess($device.SerialNumber, "Remove from AutoPilot")) {
                    try {
                        Write-Verbose "Removing device $($device.SerialNumber) from AutoPilot..."
                        
                        # Get AutoPilot device
                        $autopilotDevice = Get-AutoPilotDevice -SerialNumber $device.SerialNumber -ErrorAction SilentlyContinue
                        
                        if ($autopilotDevice) {
                            # Remove from AutoPilot
                            Remove-AutoPilotDevice -Id $autopilotDevice.Id
                            $results.AutoPilotRemovalResults.Successful += $device
                            Write-Verbose "Successfully removed device $($device.SerialNumber) from AutoPilot"
                        }
                        else {
                            Write-Verbose "Device $($device.SerialNumber) not found in AutoPilot"
                            $results.AutoPilotRemovalResults.NotFound += $device
                        }
                    }
                    catch {
                        Write-Warning "Failed to remove device $($device.SerialNumber) from AutoPilot: $($_.Exception.Message)"
                        $results.AutoPilotRemovalResults.Failed += $device
                    }
                }
                
                # Remove from Azure AD if requested
                if ($RemoveFromAzureAD -and $PSCmdlet.ShouldProcess($device.SerialNumber, "Remove from Azure AD")) {
                    try {
                        Write-Verbose "Removing device $($device.SerialNumber) from Azure AD..."
                        
                        # Check if we have Azure AD Object ID
                        if ($device.AzureADObjectId) {
                            # Remove from Azure AD
                            Remove-AzureADDevice -ObjectId $device.AzureADObjectId
                            $results.AzureADRemovalResults.Successful += $device
                            Write-Verbose "Successfully removed device $($device.SerialNumber) from Azure AD"
                        }
                        else {
                            # Try to find the device in Azure AD by device ID
                            $azureDevice = Get-AzureADDevice -Filter "DeviceId eq '$($device.AzureADDeviceId)'"
                            
                            if ($azureDevice) {
                                Remove-AzureADDevice -ObjectId $azureDevice.ObjectId
                                $results.AzureADRemovalResults.Successful += $device
                                Write-Verbose "Successfully removed device $($device.SerialNumber) from Azure AD"
                            }
                            else {
                                Write-Verbose "Device $($device.SerialNumber) not found in Azure AD"
                                $results.AzureADRemovalResults.NotFound += $device
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to remove device $($device.SerialNumber) from Azure AD: $($_.Exception.Message)"
                        $results.AzureADRemovalResults.Failed += $device
                    }
                }
            }
            
            # Export results if requested
            if ($ExportResults) {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $results.EndTime = Get-Date
                
                $resultsPath = Join-Path -Path $OutputPath -ChildPath "DeviceRemovalResults-$timestamp.json"
                $results | ConvertTo-Json -Depth 4 | Out-File -FilePath $resultsPath
                Write-Verbose "Exported results to: $resultsPath"
                
                # Export CSV summary
                $csvSummary = @()
                
                foreach ($device in $results.DevicesToRemove) {
                    $intuneStatus = if ($device -in $results.IntuneRemovalResults.Successful) { "Success" } 
                                   elseif ($device -in $results.IntuneRemovalResults.Failed) { "Failed" } 
                                   else { "Not Processed" }
                    
                    $autopilotStatus = if (-not $RemoveFromAutoPilot) { "Skipped" }
                                      elseif ($device -in $results.AutoPilotRemovalResults.Successful) { "Success" }
                                      elseif ($device -in $results.AutoPilotRemovalResults.Failed) { "Failed" }
                                      elseif ($device -in $results.AutoPilotRemovalResults.NotFound) { "Not Found" }
                                      else { "Not Processed" }
                    
                    $azureADStatus = if (-not $RemoveFromAzureAD) { "Skipped" }
                                    elseif ($device -in $results.AzureADRemovalResults.Successful) { "Success" }
                                    elseif ($device -in $results.AzureADRemovalResults.Failed) { "Failed" }
                                    elseif ($device -in $results.AzureADRemovalResults.NotFound) { "Not Found" }
                                    else { "Not Processed" }
                    
                    $csvSummary += [PSCustomObject]@{
                        SerialNumber = $device.SerialNumber
                        DeviceName = $device.DeviceName
                        Model = $device.Model
                        UserPrincipalName = $device.UserPrincipalName
                        IntuneDeviceId = $device.IntuneDeviceId
                        AzureADDeviceId = $device.AzureADDeviceId
                        AzureADObjectId = $device.AzureADObjectId
                        IntuneRemovalStatus = $intuneStatus
                        AutoPilotRemovalStatus = $autopilotStatus
                        AzureADRemovalStatus = $azureADStatus
                    }
                }
                
                $csvPath = Join-Path -Path $OutputPath -ChildPath "DeviceRemovalSummary-$timestamp.csv"
                $csvSummary | Export-Csv -Path $csvPath -NoTypeInformation
                Write-Verbose "Exported CSV summary to: $csvPath"
            }
            
            # Display results
            Write-Host "`n===== Removal Results =====" -ForegroundColor Green
            Write-Host "Intune Removal:" -ForegroundColor Green
            Write-Host "  Successful: $($results.IntuneRemovalResults.Successful.Count)" -ForegroundColor Green
            Write-Host "  Failed: $($results.IntuneRemovalResults.Failed.Count)" -ForegroundColor Red
            Write-Host "  Not Found: $($results.IntuneRemovalResults.NotFound.Count)" -ForegroundColor Yellow
            
            if ($RemoveFromAutoPilot) {
                Write-Host "`nAutoPilot Removal:" -ForegroundColor Green
                Write-Host "  Successful: $($results.AutoPilotRemovalResults.Successful.Count)" -ForegroundColor Green
                Write-Host "  Failed: $($results.AutoPilotRemovalResults.Failed.Count)" -ForegroundColor Red
                Write-Host "  Not Found: $($results.AutoPilotRemovalResults.NotFound.Count)" -ForegroundColor Yellow
            }
            
            if ($RemoveFromAzureAD) {
                Write-Host "`nAzure AD Removal:" -ForegroundColor Green
                Write-Host "  Successful: $($results.AzureADRemovalResults.Successful.Count)" -ForegroundColor Green
                Write-Host "  Failed: $($results.AzureADRemovalResults.Failed.Count)" -ForegroundColor Red
                Write-Host "  Not Found: $($results.AzureADRemovalResults.NotFound.Count)" -ForegroundColor Yellow
            }
            
            Write-Host "========================`n" -ForegroundColor Green
            
            return $results
        }
        catch {
            Write-Error "Failed to remove devices: $($_.Exception.Message)"
            throw $_
        }
    }
}
