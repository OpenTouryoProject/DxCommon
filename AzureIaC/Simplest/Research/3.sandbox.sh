yourRgName=YourRG
yourVnetName=YourVnet
yourSubnetName=YourSubnet

az group create \
  --name $yourRgName \
  --location $location

az network vnet create \
  --resource-group $yourRgName \
  --name $yourVnetName \
  --address-prefix 10.1.0.0/16 \
  --subnet-name $yourSubnetName \
  --subnet-prefix 10.1.0.0/24 \
  --location $location

vmName=YourVM1
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

az network public-ip list --output table

az vm auto-shutdown --resource-group $yourRgName --name $vmName --time 1500

