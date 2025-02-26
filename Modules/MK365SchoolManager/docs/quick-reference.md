# MK365SchoolManager Quick Reference

## 🚀 Quick Start

1. **Connect and Configure**
```powershell
# Connect
Connect-MK365Device

# Configure
Set-MK365SchoolConfig -School "Your School" -GradeLevels "7","10"
```

2. **Check Inventory**
```powershell
# Get current status
Get-MK365DeviceInventory -ExportReport
```

3. **Start Reset**
```powershell
# Basic reset
Start-MK365ResetWorkflow -GradeLevels "7","10" -NotifyStakeholders
```

## 📋 Common Tasks

### Device Management
```powershell
# Get all devices
Get-MK365DeviceInventory

# Get specific grades
Get-MK365DeviceInventory -GradeLevels "7","10"

# Check storage
Get-MK365DeviceInventory | Where-Object { $_.StorageFree -lt 10 }
```

### Reset Operations
```powershell
# Schedule reset
Start-MK365ResetWorkflow -GradeLevels "7","10" -ScheduledDate "2025-06-15"

# Check status
Get-MK365ResetStatus

# Export report
Get-MK365ResetStatus -Detailed | Export-Csv "reset_report.csv"
```

## 🔍 Monitoring

### Check Progress
```powershell
# Current status
Get-MK365ResetStatus

# Failed devices
Get-MK365ResetStatus | Where-Object Status -eq 'Failed'
```

### Generate Reports
```powershell
# Inventory report
Get-MK365DeviceInventory -ExportReport

# Reset status
Get-MK365ResetStatus -Detailed | Export-Excel "status.xlsx"
```

## ⚠️ Troubleshooting

### Common Issues
1. Connection lost: `Connect-MK365Device -Force`
2. Reset failed: Check `Get-MK365ResetStatus`
3. Low storage: Check device inventory

### Get Help
```powershell
Get-Help Start-MK365ResetWorkflow -Full
Get-Help Get-MK365DeviceInventory -Examples
```
