vmName=JumpboxVM1
vmUser=[users名]
vmPassword=[password]

az vm create \
--resource-group $azureBastionRgName \
--name $vmName \
--location $location \
--size $vmSize \
--image $vmOS \
--admin-user $vmUser \
--admin-password $vmPassword \
--vnet-name $azureBastionVnetName \
--subnet $jumpboxSubnetName \
--public-ip-address ""

az network public-ip list --output table

az vm auto-shutdown --resource-group $azureBastionRgName --name $vmName --time 1500
