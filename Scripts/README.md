# Excel-Based Device Management Scripts

## Overview

This collection of PowerShell scripts provides a simple, Excel-based approach to managing school devices. The workflow allows you to:

1. Export device inventory to Excel
2. Review and mark devices as "Keep" or "Delete" in Excel
3. Process your decisions to reset and remove devices from management systems

## Scripts Included

- **Export-DeviceInventoryForReview.ps1**: Exports device inventory from Intune to an Excel file with an Action column for decision making
- **Process-DeviceReviewDecisions.ps1**: Processes the decisions made in Excel, resetting and removing devices as specified
- **Excel-Based-Device-Management-Guide.md**: Comprehensive guide for using these scripts

## Prerequisites

- PowerShell 5.1 or higher
- Microsoft Graph PowerShell modules:
  - Microsoft.Graph.DeviceManagement
  - Microsoft.Graph.Users
  - Microsoft.Graph.Identity.DirectoryManagement
- ImportExcel module (will be installed automatically if missing)
- Appropriate permissions in Microsoft Graph

## Quick Start

1. Connect to required services:
   ```powershell
   Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","User.Read.All","Group.Read.All","Device.ReadWrite.All"
   ```

2. Export devices to Excel:
   ```powershell
   .\Export-DeviceInventoryForReview.ps1 -School "Eksempel Skole"
   ```

3. Open the generated Excel file, review devices, and mark each with "Keep" or "Delete"

4. Process your decisions:
   ```powershell
   .\Process-DeviceReviewDecisions.ps1 -ReviewFilePath "DeviceInventoryForReview-20250226.xlsx" -RemoveFromAutoPilot -RemoveFromAzureAD
   ```

## Detailed Documentation

For detailed instructions, please refer to the [Excel-Based-Device-Management-Guide.md](Excel-Based-Device-Management-Guide.md) file included in this directory.

## Features

- Export device inventory with rich details including user information, device specs, and management IDs
- Excel interface with data validation and conditional formatting for easy decision making
- Flexible filtering options by school, grade level, and device type
- Complete device management workflow including Intune reset, AutoPilot removal, and Azure AD removal
- Detailed reporting and results tracking
