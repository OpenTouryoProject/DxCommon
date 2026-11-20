vmSize=Standard_D4s_v3
vmOS=Win2019Datacenter

location=japaneast
azureBastionName=AzureBastion
azureBastionRgName=AzureBastionRG
azureBastionVnetName=AzureBastionVnet
azureBastionSubnetName=AzureBastionSubnet
jumpboxSubnetName=JumpboxSubnet
azureBastionPubIPName=AzureBastionPubIP

az group create --name $azureBastionRgName --location $location

az network vnet create \
  --resource-group $azureBastionRgName \
  --name $azureBastionVnetName \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $azureBastionSubnetName \
  --subnet-prefix 10.0.0.0/24 \
  --location $location
 
az network public-ip create \
  --resource-group $azureBastionRgName \
  --name $azureBastionPubIPName \
  --sku Standard --location $location

az network bastion create \
  --resource-group $azureBastionRgName \
  --name $azureBastionName \
  --vnet-name $azureBastionVnetName \
  --public-ip-address $azureBastionPubIPName \
  --location $location

az network vnet subnet create \
  --resource-group $azureBastionRgName \
  --vnet-name $azureBastionVnetName \
  --name $jumpboxSubnetName \
  --address-prefixes 10.0.1.0/24

