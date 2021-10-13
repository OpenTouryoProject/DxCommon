# Simplest

### Variables

#### Define
Windows
```Bash
vmSize=Standard_D4s_v3
vmOS=Win2019Datacenter

```

Ubuntu
```Bash
vmSize=Standard_E2s_v3
vmOS=UbuntuLTS

```

ResourcesGroup & Network, etc.
```Bash
location=japaneast
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

#### Check
```Bash
echo $vmSize
echo $vmOS
echo $location

echo $vmName
echo $vmUser
echo $vmPassword
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

Configure Auto-Shutdown

```Bash
az vm auto-shutdown --resource-group $azureBastionRgName --name $vmName --time 1500
```
※ UTC 1500 is JST 0000.

### Creating a Sandbox

#### Network
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
  
```

#### Virtual Machine
```Bash
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

Configure Auto-Shutdown

```Bash
az vm auto-shutdown --resource-group $yourRgName --name $vmName --time 1500
```
※ UTC 1500 is JST 0000.

### VNET Peering

#### Create peering
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

#### Check

##### VNET Peering state
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

##### List of public IP addresses
```Bash
az network public-ip list --output table
```
