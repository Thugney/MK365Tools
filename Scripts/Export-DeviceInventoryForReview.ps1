<#
.SYNOPSIS
    Exports device inventory to Excel for review and decision-making.

.DESCRIPTION
    This script exports device inventory from Microsoft Intune to an Excel file,
    adding an Action column with a dropdown menu for "Keep" or "Delete" decisions.
    The Excel file can then be reviewed manually, and decisions can be processed
    using the Process-DeviceReviewDecisions.ps1 script.

.PARAMETER School
    The name of the school to export devices for.

.PARAMETER GradeLevels
    Optional. Array of grade levels to filter devices by (e.g., "7. trinn", "10. trinn").

.PARAMETER DeviceType
    Optional. Type of devices to export. Valid values are "PC", "iPad", or "All".
    Default is "All".

.PARAMETER OutputPath
    Optional. The path where the Excel file will be saved.
    Default is "$env:USERPROFILE\Documents\DeviceReports".

.PARAMETER FileName
    Optional. The name of the Excel file.
    Default is "DeviceInventoryForReview-<date>.xlsx".

.PARAMETER OpenExcel
    Optional. If specified, the Excel file will be opened automatically after export.

.PARAMETER InstallModules
    Optional. If specified, the script will automatically install any required modules that are missing.
    Default is $true.

.EXAMPLE
    .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole"

.EXAMPLE
    .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn" -DeviceType "PC"

.NOTES
    This script will automatically check for and install required modules if they are missing.
    Required modules:
    - Microsoft.Graph.DeviceManagement
    - Microsoft.Graph.Users
    - ImportExcel
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$School,
    
    [Parameter()]
    [string[]]$GradeLevels,
    
    [Parameter()]
    [ValidateSet("PC", "iPad", "All")]
    [string]$DeviceType = "All",
    
    [Parameter()]
    [string]$OutputPath = "$env:USERPROFILE\Documents\DeviceReports",
    
    [Parameter()]
    [string]$FileName,
    
    [Parameter()]
    [switch]$OpenExcel,
    
    [Parameter()]
    [bool]$InstallModules = $true
)

# Function to check and install required modules
function Ensure-ModuleInstalled {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter()]
        [string]$MinimumVersion,
        
        [Parameter()]
        [bool]$Install = $true
    )
    
    $moduleParams = @{
        Name = $ModuleName
        ListAvailable = $true
    }
    
    if ($MinimumVersion) {
        $moduleParams.MinimumVersion = $MinimumVersion
    }
    
    $module = Get-Module @moduleParams
    
    if (-not $module) {
        if ($Install) {
            Write-Host "Module $ModuleName not found. Installing..." -ForegroundColor Yellow
            try {
                Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
                Import-Module -Name $ModuleName -Force
                Write-Host "Module $ModuleName installed successfully." -ForegroundColor Green
                return $true
            }
            catch {
                Write-Error "Failed to install module $ModuleName. Error: $($_.Exception.Message)"
                return $false
            }
        }
        else {
            Write-Error "Required module $ModuleName is not installed."
            return $false
        }
    }
    else {
        Write-Verbose "Module $ModuleName is already installed."
        return $true
    }
}

# Check and install required modules
$requiredModules = @(
    @{Name = "Microsoft.Graph.Authentication"; MinimumVersion = "1.19.0"},
    @{Name = "Microsoft.Graph.DeviceManagement"; MinimumVersion = "1.19.0"},
    @{Name = "Microsoft.Graph.Users"; MinimumVersion = "1.19.0"},
    @{Name = "ImportExcel"; MinimumVersion = "7.0.0"}
)

$modulesInstalled = $true
foreach ($module in $requiredModules) {
    $result = Ensure-ModuleInstalled -ModuleName $module.Name -MinimumVersion $module.MinimumVersion -Install $InstallModules
    if (-not $result) {
        $modulesInstalled = $false
    }
}

if (-not $modulesInstalled) {
    Write-Error "Not all required modules could be installed. Please install them manually and try again."
    return
}

# Import required modules
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module ImportExcel -ErrorAction Stop

# Ensure we're connected to Microsoft Graph
try {
    $context = Get-MgContext
    if (-not $context) {
        Write-Host "Not connected to Microsoft Graph. Connecting..." -ForegroundColor Yellow
        try {
            Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "User.Read.All", "Group.Read.All"
            Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to connect to Microsoft Graph. Error: $($_.Exception.Message)"
            return
        }
    }
    
    # Check if connected to Microsoft Graph with the right permissions
    $requiredPermissions = @('DeviceManagementManagedDevices.ReadWrite.All', 'User.Read.All', 'Group.Read.All')
    $currentPermissions = (Get-MgContext).Scopes
    
    $missingPermissions = $requiredPermissions | Where-Object { $_ -notin $currentPermissions }
    if ($missingPermissions) {
        Write-Warning "Missing required permissions: $($missingPermissions -join ', '). Reconnecting with proper permissions..."
        Disconnect-MgGraph | Out-Null
        Connect-MgGraph -Scopes $requiredPermissions
        Write-Host "Reconnected to Microsoft Graph with required permissions." -ForegroundColor Green
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

# Set default filename if not provided
if (-not $FileName) {
    $date = Get-Date -Format "yyyyMMdd"
    $FileName = "DeviceInventoryForReview-$date.xlsx"
}

# Combine path and filename
$filePath = Join-Path -Path $OutputPath -ChildPath $FileName

# Get all managed devices
Write-Host "Retrieving managed devices from Intune..." -ForegroundColor Cyan
$allDevices = Get-MgDeviceManagementManagedDevice -All

# Filter devices by school
Write-Host "Filtering devices for school: $School" -ForegroundColor Cyan
$schoolDevices = $allDevices | Where-Object { $_.ManagedDeviceName -like "*$School*" }

# Apply grade level filter if specified
if ($GradeLevels) {
    Write-Host "Filtering by grade levels: $($GradeLevels -join ', ')" -ForegroundColor Cyan
    $filteredDevices = @()
    foreach ($device in $schoolDevices) {
        foreach ($grade in $GradeLevels) {
            if ($device.ManagedDeviceName -like "*$grade*") {
                $filteredDevices += $device
                break
            }
        }
    }
    $schoolDevices = $filteredDevices
}

# Apply device type filter if specified
if ($DeviceType -ne "All") {
    Write-Host "Filtering by device type: $DeviceType" -ForegroundColor Cyan
    if ($DeviceType -eq "PC") {
        $schoolDevices = $schoolDevices | Where-Object { $_.OperatingSystem -eq "Windows" }
    }
    elseif ($DeviceType -eq "iPad") {
        $schoolDevices = $schoolDevices | Where-Object { $_.OperatingSystem -eq "iOS" -or $_.OperatingSystem -eq "iPadOS" }
    }
}

if (-not $schoolDevices -or $schoolDevices.Count -eq 0) {
    Write-Warning "No devices found matching the specified criteria."
    return
}

Write-Host "Found $($schoolDevices.Count) devices for export." -ForegroundColor Green

# Get user information for each device
$deviceData = @()
$counter = 0
$total = $schoolDevices.Count

Write-Host "Processing device details..." -ForegroundColor Cyan
foreach ($device in $schoolDevices) {
    $counter++
    Write-Progress -Activity "Processing devices" -Status "Device $counter of $total" -PercentComplete (($counter / $total) * 100)
    
    $userData = $null
    if ($device.UserId) {
        try {
            $userData = Get-MgUser -UserId $device.UserId -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Could not retrieve user data for device $($device.ManagedDeviceName): $($_.Exception.Message)"
        }
    }
    
    # Calculate storage percentage
    $storagePercentage = if ($device.TotalStorageSpaceInBytes -gt 0) {
        [math]::Round(($device.FreeStorageSpaceInBytes / $device.TotalStorageSpaceInBytes) * 100, 2)
    }
    else {
        0
    }
    
    # Convert storage to GB
    $totalStorageGB = if ($device.TotalStorageSpaceInBytes -gt 0) {
        [math]::Round($device.TotalStorageSpaceInBytes / 1GB, 2)
    }
    else {
        0
    }
    
    $freeStorageGB = if ($device.FreeStorageSpaceInBytes -gt 0) {
        [math]::Round($device.FreeStorageSpaceInBytes / 1GB, 2)
    }
    else {
        0
    }
    
    # Extract grade level from device name
    $gradeLevel = ""
    foreach ($grade in @("1. trinn", "2. trinn", "3. trinn", "4. trinn", "5. trinn", "6. trinn", "7. trinn", "8. trinn", "9. trinn", "10. trinn")) {
        if ($device.ManagedDeviceName -like "*$grade*") {
            $gradeLevel = $grade
            break
        }
    }
    
    # Create device object
    $deviceObj = [PSCustomObject]@{
        DeviceName = $device.ManagedDeviceName
        SerialNumber = $device.SerialNumber
        Model = $device.Model
        Manufacturer = $device.Manufacturer
        GradeLevel = $gradeLevel
        UserPrincipalName = $userData.UserPrincipalName
        UserDisplayName = $userData.DisplayName
        LastSyncDateTime = $device.LastSyncDateTime
        EnrolledDateTime = $device.EnrolledDateTime
        OperatingSystem = $device.OperatingSystem
        OSVersion = $device.OSVersion
        StorageTotal = $totalStorageGB
        StorageFree = $freeStorageGB
        StoragePercentageFree = $storagePercentage
        IntuneDeviceId = $device.Id
        AzureADDeviceId = $device.AzureADDeviceId
        AzureADObjectId = $device.AzureADDeviceId  # This is actually the same as AzureADDeviceId in most cases
        Action = ""  # This will be populated with dropdown in Excel
    }
    
    $deviceData += $deviceObj
}

Write-Progress -Activity "Processing devices" -Completed

# Export to Excel
Write-Host "Exporting data to Excel: $filePath" -ForegroundColor Cyan
$excelParams = @{
    Path = $filePath
    TableName = "DeviceInventory"
    WorksheetName = "Devices"
    AutoSize = $true
    FreezeTopRow = $true
    BoldTopRow = $true
    AutoFilter = $true
    ClearSheet = $true
}

$deviceData | Export-Excel @excelParams

# Add data validation for Action column
$excel = Open-ExcelPackage -Path $filePath
$worksheet = $excel.Workbook.Worksheets["Devices"]

# Find the Action column
$actionColumn = 0
for ($i = 1; $i -le $worksheet.Dimension.Columns; $i++) {
    if ($worksheet.Cells[1, $i].Value -eq "Action") {
        $actionColumn = $i
        break
    }
}

if ($actionColumn -gt 0) {
    # Add data validation for the Action column
    $validation = $worksheet.DataValidations.AddListValidation("${actionColumn}2:${actionColumn}$($deviceData.Count + 1)")
    $validation.Formula.Values.Add("Keep")
    $validation.Formula.Values.Add("Delete")
    $validation.ShowErrorMessage = $true
    $validation.ErrorTitle = "Invalid Action"
    $validation.Error = "Please select either 'Keep' or 'Delete'"
    
    # Add conditional formatting
    $keepRule = $worksheet.ConditionalFormatting.AddEqual("${actionColumn}2:${actionColumn}$($deviceData.Count + 1)")
    $keepRule.Formula = '"Keep"'
    $keepRule.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGreen)
    
    $deleteRule = $worksheet.ConditionalFormatting.AddEqual("${actionColumn}2:${actionColumn}$($deviceData.Count + 1)")
    $deleteRule.Formula = '"Delete"'
    $deleteRule.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightPink)
}

# Save and close the Excel package
Close-ExcelPackage $excel

Write-Host "Device inventory exported to: $filePath" -ForegroundColor Green
Write-Host "Total devices exported: $($deviceData.Count)" -ForegroundColor Cyan
Write-Host "Please review the Excel file and mark each device with 'Keep' or 'Delete' in the Action column." -ForegroundColor Yellow
Write-Host "After review, use the Process-DeviceReviewDecisions.ps1 script to process your decisions." -ForegroundColor Yellow

# Open Excel file if requested
if ($OpenExcel -and (Test-Path -Path $filePath)) {
    Write-Host "Opening Excel file..." -ForegroundColor Cyan
    Invoke-Item -Path $filePath
}
