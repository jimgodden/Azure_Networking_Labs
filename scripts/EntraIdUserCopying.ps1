# Description: This script is used to copy users from one Entra group to another Entra group.

# Install the Microsoft.Graph.Entra module if it's not already installed
$moduleName = 'Microsoft.Graph.Entra' 
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    # Install the module
    Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowPrerelease -Force
}

# IDs for the Old and New Entra Group ObjectIds
$Old = @{
    TenantId = ''
    GroupObjectId = ''
}
$New = @{
    TenantId = ''
    GroupObjectId = ''
}

# Recursive function to get all members of the group passed in GroupObjectId and all members of the subgroups
function Get-SubGroupMembers {
    param (
        [string]$GroupObjectId
    )

    # Get all members of the specified group
    $members = Get-EntraGroupMember -All -ObjectId $GroupObjectId

    # Cycles through the members of the group.
    # If the member is a group, then it calls the function recursively to get all members of the subgroup.
    # If the member is a user, then it adds the user to the list of users.
    $members_Users_Only = @()
    foreach ($member in $members) {
        if ($member.("@odata.type") -eq '#microsoft.graph.group') {
            $members_Users_Only += Get-SubGroupMembers -GroupObjectId $member.Id
        }
        elseif ($member.("@odata.type") -eq '#microsoft.graph.user') {
            $members_Users_Only += $member
        }
        # If the member is neither a group nor a user, then it writes a message to the console and exits the script.
        # Any instances of this message should be investigated and handled appropriately.
        else {
            Write-Host "Unknown Issue with Member ID: $($member.Id) and Name: $($member.DisplayName)"
            $read = Read-Host "Pausing the script until you press Enter to exit."
            exit
            $read
        }
    }

    # Returns the list of users
    return $members_Users_Only
}

# Function to get the email addresses of the members of the group
function Get-MemberEmailAddresses {
    param (
        [string]$TenantId,
        [string]$GroupObjectId
    )

    Connect-Entra -Scopes "Group.Read.All", "User.Read.All" -TenantId $TenantId -NoWelcome

    $members_Users_Only = @()
    $members_Users_Only = Get-SubGroupMembers -GroupObjectId $GroupObjectId

    $members_UserPrincipalNames = @()
    foreach ($member_Users_Only in $members_Users_Only) {
        $members_UserPrincipalNames += (Get-EntraUser -ObjectId $member_Users_Only.Id).UserPrincipalName
    }

    return $members_UserPrincipalNames
}

# Get the email addresses of the members of the Old and New Entra Groups
$members_UserPrincipalNames_Old = Get-MemberEmailAddresses -TenantId $Old.TenantId -GroupObjectId $Old.GroupObjectId
$members_UserPrincipalNames_New = Get-MemberEmailAddresses -TenantId $New.TenantId -GroupObjectId $New.GroupObjectId

# Compare the email addresses of the members of the Old and New Entra Groups
foreach ($member_UserPrincipalName_New in $members_UserPrincipalNames_New) {
    if ($members_UserPrincipalNames_Old -notcontains $member_UserPrincipalName_New) {
        Write-Host "User Email Address: $member_UserPrincipalName_New is not in the Old Group"
        # Remove the user from the New Group
    }
}

# Gets all users from the New Tenant so that we can more efficiently find the user by UserPrincipalName
# If we didn't do it this way, we would have to make a separate query for each user.
$users_new = Get-EntraUser -All | Select-Object -Property UserPrincipalName, Id

# Connecting to the New Tenant with Group.ReadWrite.
Connect-Entra -Scopes "Group.ReadWrite.All", "User.Read.All" -TenantId $New.TenantId -NoWelcome

foreach ($member_UserPrincipalName_Old in $members_UserPrincipalNames_Old) {
    if ($members_UserPrincipalNames_New -notcontains $member_UserPrincipalName_Old) {
        Write-Host "User Email Address: $member_UserPrincipalName_Old is not in the New Group"
        
        # Add the user to the New Group
        $member = $users_new | Where-Object { $_.UserPrincipalName -eq $member_UserPrincipalName_Old }
        if ($member) {
            Add-EntraGroupMember -ObjectId $New.GroupObjectId -RefObjectId $member.Id
        } else {
            Write-Host "User with UserPrincipalName: $member_UserPrincipalName_Old not found in the New Tenant."
        }
    }
}
