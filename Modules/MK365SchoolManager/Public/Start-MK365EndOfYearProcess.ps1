function Start-MK365EndOfYearProcess {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$School,
        
        [Parameter()]
        [string[]]$GradeLevels = @("7. trinn", "10. trinn"),
        
        [Parameter()]
        [ValidateSet('PC', 'iPad', 'All')]
        [string]$DeviceType = 'All',
        
        [Parameter()]
        [string[]]$ModelsToRetire,
        
        [Parameter()]
        [string[]]$ModelsToKeep,
        
        [Parameter()]
        [switch]$IncludeOtherGradesForRetiredModels,
        
        [Parameter()]
        [switch]$ExportInventoryReports,
        
        [Parameter()]
        [string]$ReportPath = "$env:USERPROFILE\Documents\DeviceReports",
        
        [Parameter()]
        [switch]$NotifyStakeholders,
        
        [Parameter()]
        [string[]]$NotificationEmails,
        
        [Parameter()]
        [switch]$AutoRemoveFromAutoPilot,
        
        [Parameter()]
        [switch]$AutoRemoveFromAzureAD,
        
        [Parameter()]
        [switch]$SkipConfirmation,
        
        [Parameter()]
        [datetime]$ScheduledDate
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
        
        # Create report directory if it doesn't exist
        if ($ExportInventoryReports -and -not (Test-Path -Path $ReportPath)) {
            New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created report directory: $ReportPath"
        }
        
        # Generate timestamp for reports
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        
        # Initialize result tracking
        $results = @{
            School = $School
            GradeLevels = $GradeLevels
            DeviceType = $DeviceType
            StartTime = Get-Date
            EndTime = $null
            TotalDevices = 0
            DevicesToReset = @()
            DevicesToKeep = @()
            ResetResults = @{
                Successful = @()
                Failed = @()
                Skipped = @()
            }
            AutoPilotRemovalResults = @{
                Successful = @()
                Failed = @()
            }
            AzureADRemovalResults = @{
                Successful = @()
                Failed = @()
            }
            ReportPaths = @()
        }
    }
    
    process {
        try {
            #region Step 1: Get device inventory
            Write-Verbose "Step 1: Retrieving device inventory for $School..."
            
            # Get all devices for the school
            $allDevices = Get-MK365DeviceInventory -School $School -DeviceType $DeviceType -IncludeDetails
            
            if (-not $allDevices -or $allDevices.Count -eq 0) {
                Write-Warning "No devices found for school: $School"
                return
            }
            
            $results.TotalDevices = $allDevices.Count
            Write-Verbose "Found $($allDevices.Count) devices for school: $School"
            
            # Export initial inventory if requested
            if ($ExportInventoryReports) {
                $initialReportPath = Join-Path -Path $ReportPath -ChildPath "InitialInventory-$School-$timestamp.csv"
                $allDevices | Export-Csv -Path $initialReportPath -NoTypeInformation
                $results.ReportPaths += $initialReportPath
                Write-Verbose "Exported initial inventory to: $initialReportPath"
            }
            #endregion
            
            #region Step 2: Identify devices to reset
            Write-Verbose "Step 2: Identifying devices to reset..."
            
            # Filter devices by grade level
            $gradeDevices = @()
            
            # Get users in the specified grade levels
            foreach ($gradeLevel in $GradeLevels) {
                Write-Verbose "Finding devices for grade level: $gradeLevel"
                
                # Get devices with users in the specified grade level
                $gradeUsers = Get-MgUser -All | Where-Object { 
                    $userGroups = Get-MgUserMemberOf -UserId $_.Id
                    $userGroups | Where-Object { 
                        $_.AdditionalProperties.displayName -like "*$gradeLevel*" 
                    }
                }
                
                Write-Verbose "Found $($gradeUsers.Count) users in grade level: $gradeLevel"
                
                # Find devices assigned to these users
                foreach ($user in $gradeUsers) {
                    $userDevices = $allDevices | Where-Object { $_.UserPrincipalName -eq $user.UserPrincipalName }
                    $gradeDevices += $userDevices
                }
            }
            
            $gradeDevices = $gradeDevices | Sort-Object -Property SerialNumber -Unique
            Write-Verbose "Found $($gradeDevices.Count) devices for specified grade levels"
            
            # Identify devices to reset based on model criteria
            $devicesToReset = @()
            $devicesToKeep = @()
            
            if ($ModelsToRetire) {
                # Add devices with models to retire
                $retireModelDevices = $gradeDevices | Where-Object { $_.Model -in $ModelsToRetire }
                $devicesToReset += $retireModelDevices
                Write-Verbose "Found $($retireModelDevices.Count) devices with models to retire in specified grades"
                
                # If requested, also include devices from other grades that have models to retire
                if ($IncludeOtherGradesForRetiredModels) {
                    $otherGradeRetireDevices = $allDevices | 
                        Where-Object { $_.Model -in $ModelsToRetire } | 
                        Where-Object { $_.SerialNumber -notin $gradeDevices.SerialNumber }
                    
                    $devicesToReset += $otherGradeRetireDevices
                    Write-Verbose "Found additional $($otherGradeRetireDevices.Count) devices with models to retire in other grades"
                }
                
                # Keep devices with models to keep
                if ($ModelsToKeep) {
                    $keepModelDevices = $gradeDevices | Where-Object { $_.Model -in $ModelsToKeep }
                    $devicesToKeep += $keepModelDevices
                    Write-Verbose "Found $($keepModelDevices.Count) devices with models to keep"
                }
                
                # Keep other models not specified for retirement
                $otherModelDevices = $gradeDevices | 
                    Where-Object { $_.Model -notin $ModelsToRetire } | 
                    Where-Object { (-not $ModelsToKeep) -or ($_.Model -notin $ModelsToKeep) }
                
                $devicesToKeep += $otherModelDevices
                Write-Verbose "Found $($otherModelDevices.Count) devices with other models not specified for retirement"
            }
            else {
                # If no models specified, reset all devices in the specified grades
                $devicesToReset = $gradeDevices
                Write-Verbose "No model criteria specified, will reset all $($gradeDevices.Count) devices in specified grades"
            }
            
            # Remove duplicates
            $devicesToReset = $devicesToReset | Sort-Object -Property SerialNumber -Unique
            $devicesToKeep = $devicesToKeep | Sort-Object -Property SerialNumber -Unique
            
            # Ensure no overlap between reset and keep lists
            $devicesToKeep = $devicesToKeep | Where-Object { $_.SerialNumber -notin $devicesToReset.SerialNumber }
            
            $results.DevicesToReset = $devicesToReset
            $results.DevicesToKeep = $devicesToKeep
            
            Write-Verbose "Final count: $($devicesToReset.Count) devices to reset, $($devicesToKeep.Count) devices to keep"
            
            # Export device lists if requested
            if ($ExportInventoryReports) {
                $resetDevicesPath = Join-Path -Path $ReportPath -ChildPath "DevicesToReset-$School-$timestamp.csv"
                $devicesToReset | Export-Csv -Path $resetDevicesPath -NoTypeInformation
                $results.ReportPaths += $resetDevicesPath
                Write-Verbose "Exported devices to reset to: $resetDevicesPath"
                
                $keepDevicesPath = Join-Path -Path $ReportPath -ChildPath "DevicesToKeep-$School-$timestamp.csv"
                $devicesToKeep | Export-Csv -Path $keepDevicesPath -NoTypeInformation
                $results.ReportPaths += $keepDevicesPath
                Write-Verbose "Exported devices to keep to: $keepDevicesPath"
            }
            #endregion
            
            #region Step 3: Confirm and reset devices
            if ($devicesToReset.Count -eq 0) {
                Write-Warning "No devices identified for reset. Process complete."
                return $results
            }
            
            # Display summary and confirm
            Write-Host "`n===== End of Year Process Summary =====" -ForegroundColor Cyan
            Write-Host "School: $School" -ForegroundColor Cyan
            Write-Host "Grade Levels: $($GradeLevels -join ', ')" -ForegroundColor Cyan
            Write-Host "Device Type: $DeviceType" -ForegroundColor Cyan
            Write-Host "Total Devices: $($allDevices.Count)" -ForegroundColor Cyan
            Write-Host "Devices to Reset: $($devicesToReset.Count)" -ForegroundColor Cyan
            Write-Host "Devices to Keep: $($devicesToKeep.Count)" -ForegroundColor Cyan
            
            if ($ModelsToRetire) {
                Write-Host "Models to Retire: $($ModelsToRetire -join ', ')" -ForegroundColor Cyan
            }
            
            if ($ModelsToKeep) {
                Write-Host "Models to Keep: $($ModelsToKeep -join ', ')" -ForegroundColor Cyan
            }
            
            Write-Host "===================================`n" -ForegroundColor Cyan
            
            $proceed = $true
            
            if (-not $SkipConfirmation) {
                $confirmation = Read-Host "Do you want to proceed with resetting $($devicesToReset.Count) devices? (Y/N)"
                $proceed = $confirmation -eq 'Y' -or $confirmation -eq 'y'
            }
            
            if (-not $proceed) {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                return $results
            }
            
            # Reset devices
            Write-Verbose "Step 3: Resetting devices..."
            
            # Check if we should schedule for later
            $resetParams = @{
                DeviceSerialNumbers = $devicesToReset.SerialNumber
                School = $School
                NotifyStakeholders = $NotifyStakeholders
            }
            
            if ($ScheduledDate) {
                $resetParams.ScheduledDate = $ScheduledDate
                Write-Verbose "Scheduling device resets for: $ScheduledDate"
            }
            
            # Execute reset workflow
            if ($PSCmdlet.ShouldProcess("$($devicesToReset.Count) devices", "Reset")) {
                $resetResults = Start-MK365ResetWorkflow @resetParams -Verbose
                
                # Process results
                $results.ResetResults.Successful = $resetResults.Successful
                $results.ResetResults.Failed = $resetResults.Failed
                $results.ResetResults.Skipped = $resetResults.NotEligible
                
                Write-Host "`n===== Reset Results =====" -ForegroundColor Green
                Write-Host "Successful: $($resetResults.Successful.Count)" -ForegroundColor Green
                Write-Host "Failed: $($resetResults.Failed.Count)" -ForegroundColor Red
                Write-Host "Skipped: $($resetResults.NotEligible.Count)" -ForegroundColor Yellow
                Write-Host "========================`n" -ForegroundColor Green
            }
            #endregion
            
            #region Step 4: AutoPilot and Azure AD cleanup
            # Only proceed with cleanup for successfully reset devices
            $successfulResets = $resetResults.Successful
            
            if ($successfulResets.Count -gt 0 -and $AutoRemoveFromAutoPilot) {
                Write-Verbose "Step 4a: Removing successfully reset devices from AutoPilot..."
                
                if ($PSCmdlet.ShouldProcess("$($successfulResets.Count) devices", "Remove from AutoPilot")) {
                    foreach ($device in $successfulResets) {
                        try {
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
                                $results.AutoPilotRemovalResults.Skipped += $device
                            }
                        }
                        catch {
                            Write-Warning "Failed to remove device $($device.SerialNumber) from AutoPilot: $($_.Exception.Message)"
                            $results.AutoPilotRemovalResults.Failed += $device
                        }
                    }
                    
                    Write-Host "`n===== AutoPilot Removal Results =====" -ForegroundColor Cyan
                    Write-Host "Successful: $($results.AutoPilotRemovalResults.Successful.Count)" -ForegroundColor Green
                    Write-Host "Failed: $($results.AutoPilotRemovalResults.Failed.Count)" -ForegroundColor Red
                    Write-Host "==================================`n" -ForegroundColor Cyan
                }
            }
            
            if ($successfulResets.Count -gt 0 -and $AutoRemoveFromAzureAD) {
                Write-Verbose "Step 4b: Removing successfully reset devices from Azure AD..."
                
                if ($PSCmdlet.ShouldProcess("$($successfulResets.Count) devices", "Remove from Azure AD")) {
                    foreach ($device in $successfulResets) {
                        try {
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
                                    $results.AzureADRemovalResults.Skipped += $device
                                }
                            }
                        }
                        catch {
                            Write-Warning "Failed to remove device $($device.SerialNumber) from Azure AD: $($_.Exception.Message)"
                            $results.AzureADRemovalResults.Failed += $device
                        }
                    }
                    
                    Write-Host "`n===== Azure AD Removal Results =====" -ForegroundColor Cyan
                    Write-Host "Successful: $($results.AzureADRemovalResults.Successful.Count)" -ForegroundColor Green
                    Write-Host "Failed: $($results.AzureADRemovalResults.Failed.Count)" -ForegroundColor Red
                    Write-Host "================================`n" -ForegroundColor Cyan
                }
            }
            #endregion
            
            #region Step 5: Final reporting
            # Get updated inventory
            if ($ExportInventoryReports) {
                Write-Verbose "Step 5: Generating final inventory report..."
                
                $finalInventory = Get-MK365DeviceInventory -School $School -DeviceType $DeviceType -IncludeDetails
                $finalReportPath = Join-Path -Path $ReportPath -ChildPath "FinalInventory-$School-$timestamp.csv"
                $finalInventory | Export-Csv -Path $finalReportPath -NoTypeInformation
                $results.ReportPaths += $finalReportPath
                Write-Verbose "Exported final inventory to: $finalReportPath"
                
                # Create summary report
                $summaryReportPath = Join-Path -Path $ReportPath -ChildPath "Summary-$School-$timestamp.json"
                $results.EndTime = Get-Date
                $results | ConvertTo-Json -Depth 4 | Out-File -FilePath $summaryReportPath
                $results.ReportPaths += $summaryReportPath
                Write-Verbose "Exported summary report to: $summaryReportPath"
                
                Write-Host "`n===== Report Files =====" -ForegroundColor Cyan
                foreach ($reportPath in $results.ReportPaths) {
                    Write-Host $reportPath
                }
                Write-Host "=====================`n" -ForegroundColor Cyan
            }
            #endregion
            
            # Return results
            return $results
        }
        catch {
            Write-Error "Failed to execute end-of-year process: $($_.Exception.Message)"
            throw $_
        }
    }
}
