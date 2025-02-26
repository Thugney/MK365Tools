function Set-MK365SchoolConfig {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ConfigPath = "$PSScriptRoot\..\Config\SchoolConfig.json",

        [Parameter()]
        [string]$School,

        [Parameter()]
        [string[]]$GradeLevels,

        [Parameter()]
        [hashtable]$DeviceModels = @{
            RetireModels = @()
            KeepModels = @()
        },

        [Parameter()]
        [string]$ReportPath = "$env:USERPROFILE\Documents\DeviceReports",

        [Parameter()]
        [string[]]$NotificationEmails,

        [Parameter()]
        [hashtable]$CustomSettings
    )

    begin {
        # Ensure config directory exists
        $configDir = Split-Path $ConfigPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
    }

    process {
        try {
            # Load existing config if it exists
            $config = if (Test-Path $ConfigPath) {
                Get-Content $ConfigPath | ConvertFrom-Json -AsHashtable
            } else {
                @{}
            }

            # Update config with new values
            if ($School) { $config.School = $School }
            if ($GradeLevels) { $config.GradeLevels = $GradeLevels }
            if ($DeviceModels) { $config.DeviceModels = $DeviceModels }
            if ($ReportPath) { $config.ReportPath = $ReportPath }
            if ($NotificationEmails) { $config.NotificationEmails = $NotificationEmails }
            if ($CustomSettings) {
                if (-not $config.CustomSettings) { $config.CustomSettings = @{} }
                foreach ($key in $CustomSettings.Keys) {
                    $config.CustomSettings[$key] = $CustomSettings[$key]
                }
            }

            # Add timestamp
            $config.LastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            # Save config
            $config | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Force

            Write-Verbose "Configuration saved to: $ConfigPath"
            return $config
        }
        catch {
            Write-Error "Failed to save configuration: $_"
        }
    }
}
