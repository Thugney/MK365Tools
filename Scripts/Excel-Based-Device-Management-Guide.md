# Excel-Based Device Management Guide

## Overview

This guide explains how to use the Excel-based workflow for managing school devices at the end of the year. This approach simplifies the decision-making process by allowing you to:

1. Export all devices to an Excel spreadsheet
2. Manually review and mark each device with "Keep" or "Delete"
3. Process your decisions to reset and remove devices from management systems

## Prerequisites

Before using these scripts, ensure you have:

1. PowerShell 5.1 or higher
2. The following PowerShell modules installed:
   - Microsoft.Graph.DeviceManagement
   - Microsoft.Graph.Users
   - Microsoft.Graph.Identity.DirectoryManagement (for Azure AD device removal)
   - ImportExcel (will be installed automatically if missing)

3. Appropriate permissions:
   - Microsoft Graph: `DeviceManagementManagedDevices.ReadWrite.All`, `User.Read.All`, `Group.Read.All`, `Device.ReadWrite.All`

## Workflow Steps

### Step 1: Export Device Inventory to Excel

First, export your device inventory to an Excel file for review:

```powershell
# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","User.Read.All","Group.Read.All","Device.ReadWrite.All"

# Export all devices for a school
.\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole"

# Export only specific grade levels
.\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn"

# Export only specific device types
.\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole" -DeviceType "PC"

# Specify a custom output location
.\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole" -OutputPath "C:\Reports" -FileName "DeviceReview-2025.xlsx"
```

This will create an Excel file with all devices and an "Action" column with a dropdown menu where you can select "Keep" or "Delete" for each device.

### Step 2: Review and Mark Devices in Excel

Open the generated Excel file and review each device:

1. The file contains detailed information about each device including:
   - Device name and serial number
   - Model and manufacturer
   - User information
   - Storage and OS details
   - Management IDs

2. For each device, select either "Keep" or "Delete" in the "Action" column:
   - **Keep**: The device will be left as is
   - **Delete**: The device will be reset and removed from management systems

3. You can use Excel's filtering and sorting capabilities to help with your review:
   - Filter by model to identify older devices
   - Sort by last sync date to find inactive devices
   - Filter by grade level to focus on specific groups

4. Save the Excel file when you've completed your review

### Step 3: Process Your Decisions

After completing your review, process your decisions using the following command:

```powershell
# Basic processing - only reset devices
.\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "C:\Reports\DeviceInventoryForReview-20250226.xlsx"

# Complete removal - reset and remove from all systems
.\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "C:\Reports\DeviceInventoryForReview-20250226.xlsx" `
    -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults

# Specify a custom output location for results
.\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "C:\Reports\DeviceInventoryForReview-20250226.xlsx" `
    -RemoveFromAutoPilot -RemoveFromAzureAD -ExportResults -OutputPath "C:\Reports\Results"
```

This will:
1. Read your Excel file and identify which devices you marked for deletion
2. Reset those devices in Intune
3. Optionally remove them from AutoPilot and Azure AD (if specified)
4. Generate detailed reports of the results

## Benefits of the Excel-Based Workflow

This approach offers several advantages:

1. **Visual Review**: Easily see all device information in a familiar Excel format
2. **Flexible Decision Making**: Make decisions based on any combination of factors
3. **Batch Processing**: Mark all decisions at once before processing
4. **Documentation**: The Excel file serves as documentation of your decisions
5. **Collaboration**: Share the Excel file with colleagues for input before processing

## Example Use Cases

### Scenario 1: End-of-Year Grade Level Reset

1. Export devices for specific grades:
   ```powershell
   .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole" -GradeLevels "7. trinn","10. trinn"
   ```

2. In Excel:
   - Mark older models (e.g., Surface Laptop 2) as "Delete"
   - Mark newer models (e.g., Surface Laptop 4) as "Keep"

3. Process your decisions:
   ```powershell
   .\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "DeviceInventoryForReview.xlsx" -RemoveFromAutoPilot -RemoveFromAzureAD
   ```

### Scenario 2: Condition-Based Device Retirement

1. Export all devices:
   ```powershell
   .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole"
   ```

2. In Excel:
   - Use conditional formatting to highlight devices with low storage (e.g., StorageFree < 10GB)
   - Filter for devices that haven't synced recently
   - Mark problematic devices as "Delete" and others as "Keep"

3. Process your decisions:
   ```powershell
   .\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "DeviceInventoryForReview.xlsx" -RemoveFromAutoPilot -RemoveFromAzureAD
   ```

## Troubleshooting

If you encounter issues with the Excel-based workflow:

1. **Excel Module Missing**: If you see an error about the ImportExcel module, run:
   ```powershell
   Install-Module -Name ImportExcel -Scope CurrentUser -Force
   ```

2. **Devices Without Decisions**: If some devices don't have "Keep" or "Delete" selected, they will be ignored during processing. The script will warn you about these devices.

3. **Failed Resets**: For devices that fail to reset, check:
   - Device connectivity status
   - Management state in Intune
   - Permissions for your account

4. **Verification**: After processing, you can verify the results by checking the generated reports or by checking the devices directly in Intune and Azure AD.
