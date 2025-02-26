<#
.SYNOPSIS
    Exports device inventory to an Excel file for review and decision making.

.DESCRIPTION
    This script exports device inventory from Microsoft Intune to an Excel file,
    adding an Action column where users can mark devices as "Keep" or "Delete".
    The Excel file is formatted with data validation and conditional formatting
    to make the review process easier.

.PARAMETER School
    The name of the school to retrieve devices for.

.PARAMETER GradeLevels
    Optional. The grade levels to filter devices by.

.PARAMETER DeviceType
    Optional. The type of devices to include: PC, iPad, or All (default).

.PARAMETER OutputPath
    Optional. The path where the Excel file will be saved.
    Default is "$env:USERPROFILE\Documents\DeviceReports".

.PARAMETER FileName
    Optional. The name of the Excel file.
    Default is "DeviceInventoryForReview-[current date].xlsx".

.EXAMPLE
    .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole"

.EXAMPLE
    .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn" -DeviceType "PC"

.NOTES
    Requires the Microsoft.Graph.* modules and ImportExcel module.
    Make sure you're connected to Microsoft Graph before running this script.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$School,
    
    [Parameter()]
    [string[]]$GradeLevels,
    
    [Parameter()]
    [ValidateSet('PC', 'iPad', 'All')]
    [string]$DeviceType = 'All',
    
    [Parameter()]
    [string]$OutputPath = "$env:USERPROFILE\Documents\DeviceReports",
    
    [Parameter()]
    [string]$FileName = "DeviceInventoryForReview-$(Get-Date -Format 'yyyyMMdd').xlsx"
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

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Verbose "Created output directory: $OutputPath"
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

# Import required modules
Import-Module Microsoft.Graph.DeviceManagement
Import-Module Microsoft.Graph.Users
Import-Module ImportExcel

try {
    Write-Verbose "Retrieving device inventory for $School..."
    
    # Get all managed devices
    $intuneDevices = Get-MgDeviceManagementManagedDevice -All
    
    if (-not $intuneDevices -or $intuneDevices.Count -eq 0) {
        Write-Warning "No devices found in Intune."
        return
    }
    
    Write-Verbose "Found $($intuneDevices.Count) devices in Intune. Filtering and enriching data..."
    
    # Filter devices by device type if specified
    if ($DeviceType -ne 'All') {
        if ($DeviceType -eq 'PC') {
            $intuneDevices = $intuneDevices | Where-Object { $_.OperatingSystem -eq 'Windows' }
        }
        elseif ($DeviceType -eq 'iPad') {
            $intuneDevices = $intuneDevices | Where-Object { $_.OperatingSystem -eq 'iOS' -or $_.OperatingSystem -eq 'iPadOS' }
        }
    }
    
    # Get all users to match with devices
    $allUsers = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, Department, JobTitle
    
    # Process each device to add user details and filter by school
    $enrichedDevices = @()
    
    foreach ($device in $intuneDevices) {
        # Skip devices with no user
        if (-not $device.UserId) {
            continue
        }
        
        # Get user details
        $user = $allUsers | Where-Object { $_.Id -eq $device.UserId }
        
        if (-not $user) {
            continue
        }
        
        # Check if user is from the specified school
        # Assuming school name is stored in the Department field
        if ($user.Department -ne $School) {
            continue
        }
        
        # Check if user is in the specified grade levels (if provided)
        if ($GradeLevels) {
            $userGradeLevel = $null
            
            # Try to extract grade level from JobTitle or other fields
            # This is an example - adjust based on your actual data structure
            if ($user.JobTitle -match '(\d+)\.\s*trinn') {
                $userGradeLevel = $Matches[0]
            }
            
            # Skip if user is not in the specified grade levels
            if (-not $userGradeLevel -or $userGradeLevel -notin $GradeLevels) {
                continue
            }
        }
        
        # Create enriched device object
        $enrichedDevice = [PSCustomObject]@{
            Action = ""  # Empty column for "Keep" or "Delete"
            DeviceName = $device.DeviceName
            SerialNumber = $device.SerialNumber
            Model = $device.Model
            Manufacturer = $device.Manufacturer
            UserPrincipalName = $user.UserPrincipalName
            UserDisplayName = $user.DisplayName
            LastLoggedOnUser = $device.EmailAddress
            OSVersion = $device.OSVersion
            StorageTotal = [math]::Round($device.TotalStorageSpaceInBytes / 1GB, 2)
            StorageFree = [math]::Round($device.FreeStorageSpaceInBytes / 1GB, 2)
            LastSyncDateTime = $device.LastSyncDateTime
            EnrollmentDateTime = $device.EnrolledDateTime
            GradeLevel = $user.JobTitle
            School = $user.Department
            IntuneDeviceId = $device.Id
            AzureADDeviceId = $device.AzureADDeviceId
            AzureADObjectId = $device.AzureADObjectId
        }
        
        $enrichedDevices += $enrichedDevice
    }
    
    if (-not $enrichedDevices -or $enrichedDevices.Count -eq 0) {
        Write-Warning "No devices found matching the specified criteria."
        return
    }
    
    Write-Verbose "Found $($enrichedDevices.Count) devices matching the criteria."
    
    # Prepare the output file path
    $outputFilePath = Join-Path -Path $OutputPath -ChildPath $FileName
    
    # Export to Excel
    Write-Verbose "Exporting inventory to Excel: $outputFilePath"
    
    $excelParams = @{
        Path = $outputFilePath
        WorksheetName = "Devices"
        TableName = "DeviceInventory"
        AutoSize = $true
        FreezeTopRow = $true
        BoldTopRow = $true
        AutoFilter = $true
    }
    
    # Export to Excel
    $enrichedDevices | Export-Excel @excelParams
    
    # Add conditional formatting for the Action column
    $excel = Open-ExcelPackage -Path $outputFilePath
    $worksheet = $excel.Workbook.Worksheets["Devices"]
    
    # Add data validation for the Action column (dropdown with Keep/Delete)
    $dataValidation = $worksheet.DataValidations.AddListValidation("A2:A$($enrichedDevices.Count + 1)")
    $dataValidation.Formula.Values.Add("Keep")
    $dataValidation.Formula.Values.Add("Delete")
    
    # Add conditional formatting (green for Keep, red for Delete)
    $keepRule = Add-ConditionalFormatting -Worksheet $worksheet -Address "A2:A$($enrichedDevices.Count + 1)" -RuleType Equal -ConditionValue "Keep" -BackgroundColor Green -PassThru
    $deleteRule = Add-ConditionalFormatting -Worksheet $worksheet -Address "A2:A$($enrichedDevices.Count + 1)" -RuleType Equal -ConditionValue "Delete" -BackgroundColor Red -PassThru
    
    # Save and close the Excel package
    Close-ExcelPackage $excel
    
    Write-Host "Inventory exported to: $outputFilePath" -ForegroundColor Green
    Write-Host "Please review the file and mark each device with 'Keep' or 'Delete' in the Action column." -ForegroundColor Yellow
    Write-Host "After review, use the Process-DeviceReviewDecisions.ps1 script to process your decisions." -ForegroundColor Yellow
    
    return $outputFilePath
}
catch {
    Write-Error "Failed to export device inventory: $($_.Exception.Message)"
}
