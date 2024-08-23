Install-Module -Name Microsoft.Graph.Entra -Repository PSGallery -Scope CurrentUser -AllowPrerelease -Force

$TenantId_Old = ''
$group_ObjectId_Old = ''

$TenantId_New = ''
$group_ObjectId_New = ''

$groupScope = 'Group.ReadWrite.All'
$userScope = 'User.ReadWrite.All'

Connect-Entra -Scopes $groupScope, $userScope -TenantId $TenantId_Old

$members_Old = Get-EntraGroupMember -All -ObjectId $group_ObjectId_Old

$members_Old_Groups = $members_Old | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
$members_Old_Users = $members_Old | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }

$members_Old_UserEmailAddresses = @()

foreach ($members_Old_User in $members_Old_Users) {
    $members_Old_UserEmailAddresses += (Get-EntraUser -ObjectId $members_Old_User.Id).mail
}







Connect-Entra -Scopes $groupScope, $userScope -TenantId $TenantId_New

$members_New = Get-EntraGroupMember -All -ObjectId $group_ObjectId_New

$members_New_Groups = $members_New | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
$members_New_Users = $members_New | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }

$members_New_UserEmailAddresses = @()

foreach ($members_New_User in $members_New_Users) {
    $members_New_UserEmailAddresses += (Get-EntraUser -ObjectId $members_New_User.Id).mail
}