function Start-MK365ResetWorkflow {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string[]]$GradeLevels,

        [Parameter()]
        [ValidateSet('PC', 'iPad', 'All')]
        [string]$DeviceType = 'All',

        [Parameter()]
        [string]$School,

        [Parameter()]
        [datetime]$ScheduledDate = (Get-Date),

        [Parameter()]
        [switch]$NotifyStakeholders,

        [Parameter()]
        [switch]$WhatIf
    )

    begin {
        # Verify connection
        try {
            $context = Get-MgContext
            if (-not $context) {
                throw "Not connected to Microsoft Graph. Please connect using Connect-MgGraph first."
            }
        }
        catch {
            throw "Failed to verify Microsoft Graph connection: $_"
        }

        # Initialize tracking variables
        $script:resetResults = @{
            Successful = @()
            Failed = @()
            Pending = @()
            NotEligible = @()
        }
    }

    process {
        try {
            # Get device inventory
            Write-Verbose "Retrieving device inventory..."
            $devices = Get-MK365DeviceInventory -DeviceType $DeviceType -GradeLevels $GradeLevels -School $School

            # Filter eligible devices
            $eligibleDevices = $devices | Where-Object {
                $_.ComplianceState -eq 'Compliant' -and
                $_.ManagementState -eq 'Managed'
            }

            Write-Verbose "Found $($eligibleDevices.Count) eligible devices for reset"

            foreach ($device in $eligibleDevices) {
                if ($PSCmdlet.ShouldProcess($device.SerialNumber, "Reset device")) {
                    try {
                        # 1. Initiate device reset using latest Graph cmdlets
                        Write-Verbose "Initiating reset for device: $($device.SerialNumber)"
                        
                        # New Graph cmdlet for device wipe
                        $params = @{
                            keepEnrollmentData = $false
                            keepUserData = $false
                            useProtectedWipe = $true
                        }
                        
                        Invoke-MgWipeDeviceManagementManagedDevice -ManagedDeviceId $device.IntuneDeviceId -BodyParameter $params

                        # 2. Track reset status
                        $script:resetResults.Pending += $device

                        # 3. Remove from AutoPilot using latest cmdlets
                        Write-Verbose "Removing device from AutoPilot: $($device.SerialNumber)"
                        $autopilotDevice = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity `
                            -Filter "serialNumber eq '$($device.SerialNumber)'"
                        
                        if ($autopilotDevice) {
                            Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity `
                                -WindowsAutopilotDeviceIdentityId $autopilotDevice.Id
                        }

                        # 4. Remove from Azure AD using latest cmdlets
                        Write-Verbose "Removing device from Azure AD: $($device.SerialNumber)"
                        if ($device.AzureADObjectId) {
                            Remove-MgDevice -DeviceId $device.AzureADObjectId
                        }

                        # 5. Update device category
                        if ($device.IntuneDeviceId) {
                            $updateParams = @{
                                deviceCategoryDisplayName = "Reset Pending"
                            }
                            Update-MgDeviceManagementManagedDevice `
                                -ManagedDeviceId $device.IntuneDeviceId `
                                -BodyParameter $updateParams
                        }

                        # Mark as successful
                        $script:resetResults.Successful += $device
                        $script:resetResults.Pending = $script:resetResults.Pending | 
                            Where-Object { $_.SerialNumber -ne $device.SerialNumber }

                        # Log success
                        Write-Verbose "Successfully processed device: $($device.SerialNumber)"
                    }
                    catch {
                        Write-Error "Failed to process device $($device.SerialNumber): $_"
                        $script:resetResults.Failed += $device
                    }
                }
            }

            # Generate and send report
            if ($NotifyStakeholders) {
                $reportData = [PSCustomObject]@{
                    Timestamp = Get-Date
                    School = $School
                    GradeLevels = $GradeLevels
                    DeviceType = $DeviceType
                    TotalDevices = $devices.Count
                    EligibleDevices = $eligibleDevices.Count
                    SuccessfulResets = $script:resetResults.Successful.Count
                    FailedResets = $script:resetResults.Failed.Count
                    PendingResets = $script:resetResults.Pending.Count
                    Details = $script:resetResults
                }

                # Export report
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $reportPath = Join-Path $env:USERPROFILE "Documents\DeviceReports\ResetReport-$timestamp.json"
                $reportData | ConvertTo-Json -Depth 10 | Out-File $reportPath

                Write-Verbose "Reset report saved to: $reportPath"

                # Send notification using Graph API
                $mailParams = @{
                    Message = @{
                        Subject = "Device Reset Report - $timestamp"
                        Body = @{
                            ContentType = "HTML"
                            Content = "Device reset operation completed. See attached report."
                        }
                        ToRecipients = @(
                            @{
                                EmailAddress = @{
                                    Address = "it@school.com"
                                }
                            }
                        )
                        Attachments = @(
                            @{
                                "@odata.type" = "#microsoft.graph.fileAttachment"
                                Name = "ResetReport-$timestamp.json"
                                ContentBytes = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($reportPath))
                            }
                        )
                    }
                }

                Send-MgUserMail -UserId $context.Account -BodyParameter $mailParams
            }

            # Return results
            return $script:resetResults
        }
        catch {
            Write-Error "Failed to execute reset workflow: $_"
        }
    }
}
