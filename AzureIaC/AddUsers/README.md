# AddUsers

### Variables

#### Define

```PowerShell
$subscriptionID = (Get-AzContext).Subscription.Id
```

#### Check
...

### Creating a custom role

```PowerShell
$subscriptionID = (Get-AzContext).Subscription.Id

$role = Get-AzRoleDefinition "Virtual Machine Contributor"
$role.Id = $Null
$role.Name = "仮想マシンの起動と停止"
$role.Description = "仮想マシンの起動と停止、再起動ができます"
$role.Actions.Clear()
$role.Actions.Add("Microsoft.DevTestLab/schedules/*")
$role.Actions.Add("Microsoft.Compute/virtualMachines/write")
$role.Actions.Add("Microsoft.Compute/VirtualMachines/start/action")
$role.Actions.Add("Microsoft.Compute/VirtualMachines/restart/action")
$role.Actions.Add("Microsoft.Compute/VirtualMachines/deallocate/action")
$role.Actions.Add("Microsoft.Storage/*/read")
$role.Actions.Add("Microsoft.Network/*/read")
$role.Actions.Add("Microsoft.Compute/*/read")
$role.Actions.Add("Microsoft.Authorization/*/read")
$role.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")
$role.Actions.Add("Microsoft.ResourceHealth/availabilityStatuses/read")
$role.Actions.Add("Microsoft.Insights/alertRules/*")
$role.Actions.Add("Microsoft.Support/*")
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("/subscriptions/" + $subscriptionID)
New-AzRoleDefinition -Role $role

$role = Get-AzRoleDefinition "Virtual Machine Contributor"
$role.Id = $Null
$role.Name = "仮想マシン作成のためVMCに追加する権限"
$role.Description = "仮想マシンの作成のためVirtual Machine Contributor(VMC)にNSGのreadm/writeを追加する。"
$role.Actions.Clear()
$role.Actions.Add("Microsoft.Network/networkSecurityGroups/read")
$role.Actions.Add("Microsoft.Network/networkSecurityGroups/write")
$role.Actions.Add("Microsoft.Compute/snapshots/read")
$role.Actions.Add("Microsoft.Compute/snapshots/write")
$role.Actions.Add("Microsoft.Compute/disks/beginGetAccess/action")
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("/subscriptions/" + $subscriptionID)
New-AzRoleDefinition -Role $role

$role = Get-AzRoleDefinition "Virtual Machine Contributor"
$role.Id = $Null
$role.Name = "Azure Cloud Shellの実行のために追加する権限"
$role.Description = "Azure Cloud Shellの実行のためstorageAccountsのreadm/writeを追加する。"
$role.Actions.Clear()
$role.Actions.Add("Microsoft.Storage/storageAccounts/read")
$role.Actions.Add("Microsoft.Storage/storageAccounts/write")
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("/subscriptions/" + $subscriptionID)
New-AzRoleDefinition -Role $role

```

### Invite users

```PowerShell
$mailAddress = "xxxx@yyyy"

Connect-AzureAD

New-AzureADMSInvitation `
  -InvitedUserDisplayName $mailAddress `
  -InvitedUserEmailAddress $mailAddress `
  -InviteRedirectURL https://myapps.microsoft.com `
  -SendInvitationMessage $true

Get-AzureADUser -Filter "UserType eq 'Guest'"

```

### Grant them permissions by role

#### ResourcesGroup

```PowerShell
$emailOrUserprincipalname = "<emailOrUserprincipalname>"
$yourRgName="YourRG"

New-AzRoleAssignment `
-SignInName $emailOrUserprincipalname `
-RoleDefinitionName "Virtual Machine Contributor" `
-ResourceGroupName $yourRgName

New-AzRoleAssignment `
-SignInName $emailOrUserprincipalname `
-RoleDefinitionName "仮想マシン作成のためVMCに追加する権限" `
-ResourceGroupName $yourRgName

New-AzRoleAssignment `
-SignInName $emailOrUserprincipalname `
-RoleDefinitionName "Azure Cloud Shellの実行のために追加する権限" `
-ResourceGroupName cloud-shell-storage-southeastasia

```

#### Subscription

```PowerShell
$emailOrUserprincipalname = "<emailOrUserprincipalname>"
$subscriptionID = (Get-AzContext).Subscription.Id

New-AzRoleAssignment `
-SignInName $emailOrUserprincipalname `
-RoleDefinitionName "仮想マシンの起動と停止" `
-Scope /subscriptions/$subscriptionID

```

### Check

#### Exec the Cloud Shell

```Bash
az account list --output table
```

#### Create VM

```Bash
vmSize=Standard_F4
vmOS=Win2019Datacenter
location=japanwest
yourRgName=YourRG
yourVnetName=YourVnet
yourSubnetName=YourSubnet
vmName=YourVM2
vmUser=[users名]
vmPassword=[password]

az vm create \
--resource-group $yourRgName \
--name $vmName \
--location $location \
--size $vmSize \
--image $vmOS \
--admin-user $vmUser \
--admin-password $vmPassword \
--vnet-name $yourVnetName \
--subnet $yourSubnetName \
--public-ip-address ""
```
