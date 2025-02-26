<#
.SYNOPSIS
    Processes device review decisions from an Excel file.

.DESCRIPTION
    This script reads an Excel file containing device inventory with "Keep" or "Delete"
    decisions in the Action column. It processes devices marked for deletion by resetting
    them in Intune and optionally removing them from AutoPilot and Azure AD.

.PARAMETER ReviewFilePath
    The path to the Excel file containing the device review decisions.

.PARAMETER RemoveFromAutoPilot
    If specified, devices marked for deletion will also be removed from AutoPilot.

.PARAMETER RemoveFromAzureAD
    If specified, devices marked for deletion will also be removed from Azure AD (Entra ID).

.PARAMETER ExportResults
    If specified, detailed results will be exported to CSV and JSON files.

.PARAMETER OutputPath
    Optional. The path where the results will be saved.
    Default is "$env:USERPROFILE\Documents\DeviceReports".

.EXAMPLE
    .\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "C:\Reports\DeviceInventoryForReview.xlsx"

.EXAMPLE
    .\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "C:\Reports\DeviceInventoryForReview.xlsx" -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults

.NOTES
    Requires the Microsoft.Graph.* modules, AzureAD module, and ImportExcel module.
    Make sure you're connected to Microsoft Graph and AzureAD before running this script.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$ReviewFilePath,
    
    [Parameter()]
    [switch]$RemoveFromAutoPilot,
    
    [Parameter()]
    [switch]$RemoveFromAzureAD,
    
    [Parameter()]
    [switch]$ExportResults,
    
    [Parameter()]
    [string]$OutputPath = "$env:USERPROFILE\Documents\DeviceReports"
)

# Ensure we're connected to Microsoft Graph
try {
    $context = Get-MgContext
    if (-not $context) {
        Write-Error "Not connected to Microsoft Graph. Please connect using Connect-MgGraph first."
        return
    }
}
catch {
    Write-Error "Failed to verify Microsoft Graph connection: $($_.Exception.Message)"
    return
}

# Check for AzureAD module if needed
if ($RemoveFromAzureAD) {
    try {
        $azureADModule = Get-Module -Name AzureAD -ListAvailable
        if (-not $azureADModule) {
            Write-Error "AzureAD module is required for removing devices from Azure AD. Please install it using: Install-Module AzureAD -Scope CurrentUser"
            return
        }
        
        # Check if connected to AzureAD
        try {
            $azureADConnection = Get-AzureADCurrentSessionInfo -ErrorAction Stop
        }
        catch {
            Write-Error "Not connected to Azure AD. Please connect using Connect-AzureAD first."
            return
        }
    }
    catch {
        Write-Error "AzureAD module check failed: $($_.Exception.Message)"
        return
    }
}

# Check if ImportExcel module is available
if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
    Write-Warning "ImportExcel module not found. Installing..."
    try {
        Install-Module -Name ImportExcel -Scope CurrentUser -Force
    }
    catch {
        Write-Error "Failed to install ImportExcel module. Please install it manually: Install-Module -Name ImportExcel -Scope CurrentUser"
        return
    }
}

# Create output directory if it doesn't exist and export is requested
if ($ExportResults -and -not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Verbose "Created output directory: $OutputPath"
}

# Import required modules
Import-Module Microsoft.Graph.DeviceManagement
Import-Module ImportExcel
if ($RemoveFromAzureAD) {
    Import-Module AzureAD
}

# Initialize results tracking
$results = @{
    StartTime = Get-Date
    EndTime = $null
    TotalDevices = 0
    DevicesToKeep = @()
    DevicesToDelete = @()
    ResetResults = @{
        Successful = @()
        Failed = @()
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

try {
    # Verify the review file exists
    if (-not (Test-Path -Path $ReviewFilePath)) {
        Write-Error "Review file not found: $ReviewFilePath"
        return
    }
    
    # Import the Excel file
    Write-Verbose "Importing review decisions from: $ReviewFilePath"
    $reviewData = Import-Excel -Path $ReviewFilePath
    
    if (-not $reviewData -or $reviewData.Count -eq 0) {
        Write-Error "No data found in the review file."
        return
    }
    
    $results.TotalDevices = $reviewData.Count
    
    # Filter devices based on Action column
    $devicesToKeep = $reviewData | Where-Object { $_.Action -eq "Keep" }
    $devicesToDelete = $reviewData | Where-Object { $_.Action -eq "Delete" }
    
    $results.DevicesToKeep = $devicesToKeep
    $results.DevicesToDelete = $devicesToDelete
    
    Write-Verbose "Found $($devicesToKeep.Count) devices to keep and $($devicesToDelete.Count) devices to delete."
    
    # Check if there are devices without a decision
    $devicesWithoutDecision = $reviewData | Where-Object { $_.Action -ne "Keep" -and $_.Action -ne "Delete" }
    if ($devicesWithoutDecision -and $devicesWithoutDecision.Count -gt 0) {
        Write-Warning "Found $($devicesWithoutDecision.Count) devices without a Keep/Delete decision. These will be ignored."
        
        # Display the first 5 devices without a decision
        $devicesWithoutDecision | Select-Object -First 5 | ForEach-Object {
            Write-Warning "Device without decision: $($_.DeviceName) ($($_.SerialNumber))"
        }
        
        if ($devicesWithoutDecision.Count -gt 5) {
            Write-Warning "... and $($devicesWithoutDecision.Count - 5) more devices without decisions."
        }
    }
    
    # Display summary and confirm
    Write-Host "`n===== Device Processing Summary =====" -ForegroundColor Cyan
    Write-Host "Total devices: $($reviewData.Count)" -ForegroundColor Cyan
    Write-Host "Devices to keep: $($devicesToKeep.Count)" -ForegroundColor Green
    Write-Host "Devices to delete: $($devicesToDelete.Count)" -ForegroundColor Red
    Write-Host "Devices without decision: $($devicesWithoutDecision.Count)" -ForegroundColor Yellow
    Write-Host "Remove from Intune: Yes" -ForegroundColor Cyan
    Write-Host "Remove from AutoPilot: $($RemoveFromAutoPilot)" -ForegroundColor Cyan
    Write-Host "Remove from Azure AD: $($RemoveFromAzureAD)" -ForegroundColor Cyan
    Write-Host "==============================`n" -ForegroundColor Cyan
    
    if ($devicesToDelete.Count -eq 0) {
        Write-Warning "No devices marked for deletion. Nothing to do."
        return $results
    }
    
    # Confirm before proceeding
    if (-not $PSCmdlet.ShouldProcess("$($devicesToDelete.Count) devices", "Reset and remove")) {
        Write-Warning "Operation cancelled by user."
        return $results
    }
    
    # Process devices marked for deletion
    foreach ($device in $devicesToDelete) {
        # Reset the device in Intune
        if ($PSCmdlet.ShouldProcess($device.SerialNumber, "Reset device in Intune")) {
            try {
                Write-Verbose "Resetting device $($device.DeviceName) ($($device.SerialNumber))..."
                
                # Perform device reset
                Invoke-MgDeviceManagementManagedDeviceWipe -ManagedDeviceId $device.IntuneDeviceId
                
                $results.ResetResults.Successful += $device
                Write-Verbose "Successfully initiated reset for device $($device.DeviceName)"
            }
            catch {
                Write-Warning "Failed to reset device $($device.DeviceName): $($_.Exception.Message)"
                $results.ResetResults.Failed += $device
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
        
        $resultsPath = Join-Path -Path $OutputPath -ChildPath "DeviceProcessingResults-$timestamp.json"
        $results | ConvertTo-Json -Depth 4 | Out-File -FilePath $resultsPath
        Write-Verbose "Exported results to: $resultsPath"
        
        # Export CSV summary
        $csvSummary = @()
        
        foreach ($device in $devicesToDelete) {
            $resetStatus = if ($device -in $results.ResetResults.Successful) { "Success" } 
                         elseif ($device -in $results.ResetResults.Failed) { "Failed" } 
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
                ResetStatus = $resetStatus
                AutoPilotRemovalStatus = $autopilotStatus
                AzureADRemovalStatus = $azureADStatus
            }
        }
        
        $csvPath = Join-Path -Path $OutputPath -ChildPath "DeviceProcessingSummary-$timestamp.csv"
        $csvSummary | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Verbose "Exported CSV summary to: $csvPath"
        
        # Update the original Excel file with results
        $excel = Open-ExcelPackage -Path $ReviewFilePath
        $worksheet = $excel.Workbook.Worksheets["Devices"]
        
        # Add a new worksheet for results
        $resultsSheet = Add-Worksheet -ExcelPackage $excel -WorksheetName "Processing Results"
        
        # Add summary to the results sheet
        $resultsSheet.Cells["A1"].Value = "Device Processing Results"
        $resultsSheet.Cells["A1:E1"].Merge = $true
        $resultsSheet.Cells["A1"].Style.Font.Bold = $true
        $resultsSheet.Cells["A1"].Style.Font.Size = 14
        
        $resultsSheet.Cells["A3"].Value = "Total Devices:"
        $resultsSheet.Cells["B3"].Value = $results.TotalDevices
        
        $resultsSheet.Cells["A4"].Value = "Devices Kept:"
        $resultsSheet.Cells["B4"].Value = $devicesToKeep.Count
        
        $resultsSheet.Cells["A5"].Value = "Devices Deleted:"
        $resultsSheet.Cells["B5"].Value = $devicesToDelete.Count
        
        $resultsSheet.Cells["A6"].Value = "Reset Successful:"
        $resultsSheet.Cells["B6"].Value = $results.ResetResults.Successful.Count
        
        $resultsSheet.Cells["A7"].Value = "Reset Failed:"
        $resultsSheet.Cells["B7"].Value = $results.ResetResults.Failed.Count
        
        $resultsSheet.Cells["A9"].Value = "Processing Date:"
        $resultsSheet.Cells["B9"].Value = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Add the CSV summary to the results sheet
        $csvSummary | Export-Excel -ExcelPackage $excel -WorksheetName "Processing Results" -TableName "ProcessingResults" -AutoSize -StartRow 12
        
        # Save and close the Excel package
        Close-ExcelPackage $excel -Show
    }
    
    # Display results
    Write-Host "`n===== Processing Results =====" -ForegroundColor Green
    Write-Host "Device Reset:" -ForegroundColor Green
    Write-Host "  Successful: $($results.ResetResults.Successful.Count)" -ForegroundColor Green
    Write-Host "  Failed: $($results.ResetResults.Failed.Count)" -ForegroundColor Red
    
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
    Write-Error "Failed to process device review decisions: $($_.Exception.Message)"
}
