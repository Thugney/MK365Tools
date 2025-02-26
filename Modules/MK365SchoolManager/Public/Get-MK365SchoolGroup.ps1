function Get-MK365SchoolGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$School,
        
        [Parameter()]
        [string[]]$GradeLevels,
        
        [Parameter()]
        [switch]$IncludeMembers,
        
        [Parameter()]
        [switch]$ExportReport,
        
        [Parameter()]
        [string]$OutputPath = "$env:USERPROFILE\Documents\SchoolReports"
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
        
        # Create output directory if it doesn't exist and export is requested
        if ($ExportReport -and -not (Test-Path -Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created output directory: $OutputPath"
        }
    }
    
    process {
        try {
            # Get all groups
            Write-Verbose "Retrieving groups for school: $School"
            $allGroups = Get-MgGroup -All
            
            if (-not $allGroups -or $allGroups.Count -eq 0) {
                Write-Warning "No groups found"
                return @()
            }
            
            Write-Verbose "Found $($allGroups.Count) groups in total"
            
            # Filter groups by school
            $schoolGroups = $allGroups | Where-Object { 
                $_.DisplayName -like "*$School*" -or 
                $_.Description -like "*$School*" -or
                $_.Mail -like "*$School*"
            }
            
            Write-Verbose "Found $($schoolGroups.Count) groups matching school: $School"
            
            # Filter by grade levels if specified
            if ($GradeLevels) {
                $filteredGroups = @()
                foreach ($gradeLevel in $GradeLevels) {
                    $gradeGroups = $schoolGroups | Where-Object { 
                        $_.DisplayName -like "*$gradeLevel*" -or 
                        $_.Description -like "*$gradeLevel*"
                    }
                    $filteredGroups += $gradeGroups
                }
                $schoolGroups = $filteredGroups | Sort-Object -Property Id -Unique
                Write-Verbose "Found $($schoolGroups.Count) groups matching grade levels: $($GradeLevels -join ', ')"
            }
            
            # Create custom objects with relevant properties
            $groupObjects = @()
            
            foreach ($group in $schoolGroups) {
                $groupObject = [PSCustomObject]@{
                    Id = $group.Id
                    DisplayName = $group.DisplayName
                    Description = $group.Description
                    Mail = $group.Mail
                    GroupTypes = $group.GroupTypes -join ','
                    Visibility = $group.Visibility
                    CreatedDateTime = $group.CreatedDateTime
                    MemberCount = 0
                    Members = @()
                }
                
                # Include members if requested
                if ($IncludeMembers) {
                    try {
                        $members = Get-MgGroupMember -GroupId $group.Id -All
                        $groupObject.MemberCount = $members.Count
                        
                        foreach ($member in $members) {
                            try {
                                # Get user details
                                $user = Get-MgUser -UserId $member.Id -ErrorAction SilentlyContinue
                                
                                if ($user) {
                                    $memberObject = [PSCustomObject]@{
                                        Id = $user.Id
                                        DisplayName = $user.DisplayName
                                        UserPrincipalName = $user.UserPrincipalName
                                        Mail = $user.Mail
                                        JobTitle = $user.JobTitle
                                        Department = $user.Department
                                        OfficeLocation = $user.OfficeLocation
                                    }
                                    
                                    $groupObject.Members += $memberObject
                                }
                            }
                            catch {
                                Write-Verbose "Could not retrieve details for member $($member.Id): $($_.Exception.Message)"
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Could not retrieve members for group $($group.DisplayName): $($_.Exception.Message)"
                    }
                }
                else {
                    # Just get the count if members aren't requested
                    try {
                        $members = Get-MgGroupMember -GroupId $group.Id -All
                        $groupObject.MemberCount = $members.Count
                    }
                    catch {
                        Write-Verbose "Could not retrieve member count for group $($group.DisplayName): $($_.Exception.Message)"
                    }
                }
                
                $groupObjects += $groupObject
            }
            
            # Export report if requested
            if ($ExportReport) {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $reportPath = Join-Path -Path $OutputPath -ChildPath "SchoolGroups-$School-$timestamp.csv"
                
                # Export basic group info
                $groupObjects | Select-Object -Property Id, DisplayName, Description, Mail, GroupTypes, Visibility, CreatedDateTime, MemberCount |
                    Export-Csv -Path $reportPath -NoTypeInformation
                
                Write-Verbose "Exported group report to: $reportPath"
                
                # Export members if included
                if ($IncludeMembers) {
                    $membersReportPath = Join-Path -Path $OutputPath -ChildPath "GroupMembers-$School-$timestamp.csv"
                    
                    $membersList = @()
                    foreach ($group in $groupObjects) {
                        foreach ($member in $group.Members) {
                            $memberEntry = [PSCustomObject]@{
                                GroupId = $group.Id
                                GroupName = $group.DisplayName
                                UserId = $member.Id
                                UserDisplayName = $member.DisplayName
                                UserPrincipalName = $member.UserPrincipalName
                                UserMail = $member.Mail
                                JobTitle = $member.JobTitle
                                Department = $member.Department
                                OfficeLocation = $member.OfficeLocation
                            }
                            
                            $membersList += $memberEntry
                        }
                    }
                    
                    $membersList | Export-Csv -Path $membersReportPath -NoTypeInformation
                    Write-Verbose "Exported group members report to: $membersReportPath"
                }
            }
            
            return $groupObjects
        }
        catch {
            Write-Error "Failed to retrieve school groups: $($_.Exception.Message)"
            throw $_
        }
    }
}
