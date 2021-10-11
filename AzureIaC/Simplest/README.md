# Simplest

### Define variables

```Bash
vmSize=Standard_F2s_v2
vmOS=Win2019Datacenter

location=japanwest
azureBastionName=AzureBastion
azureBastionRgName=AzureBastionRG
azureBastionVnetName=AzureBastionVnet
azureBastionSubnetName=AzureBastionSubnet
jumpboxSubnetName=JumpboxSubnet
azureBastionPubIPName=AzureBastionPubIP

yourRgName=YourRG
yourVnetName=YourVnet
yourSubnetName=YourSubnet

```

### Creating an Azure Bastion
```Bash
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

```

### Creating an Jumpbox Vm
```Bash

vmName=JumpboxVM1
vmUser=[users名]
vmPassword=[password]

az network vnet subnet create \
  --resource-group $azureBastionRgName \
  --vnet-name $azureBastionVnetName \
  --name $jumpboxSubnetName \
  --address-prefixes 10.0.1.0/24

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

```

### Creating a Sandbox
```Bash
vmName=YourVM1
vmUser=[users名]
vmPassword=[password]

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

### VNET Peering

```Bash
vNetPeering1Name=AzureBastionVnet-YourVnet
vNetPeering2Name=YourVnet-AzureBastionVnet

vNet1Id=$(az network vnet show \
  --resource-group $azureBastionRgName \
  --name $azureBastionVnetName \
  --query id --out tsv)
  
vNet2Id=$(az network vnet show \
  --resource-group $yourRgName \
  --name $yourVnetName \
  --query id \
  --out tsv)

echo $vNet1Id
echo $vNet2Id

az network vnet peering create \
  --name $vNetPeering1Name \
  --resource-group $azureBastionRgName \
  --vnet-name $azureBastionVnetName \
  --remote-vnet $vNet2Id \
  --allow-vnet-access

az network vnet peering create \
  --name $vNetPeering2Name \
  --resource-group $yourRgName \
  --vnet-name $yourVnetName \
  --remote-vnet $vNet1Id \
  --allow-vnet-access
```

### Check

#### VNET Peering state
```Bash
az network vnet peering show \
  --name $vNetPeering1Name \
  --resource-group $azureBastionRgName \
  --vnet-name $azureBastionVnetName \
  --query peeringState

az network vnet peering show \
  --name $vNetPeering2Name \
  --resource-group $yourRgName \
  --vnet-name $yourVnetName \
  --query peeringState
```

#### List of public IP addresses
```Bash
az network public-ip list --output table
```
