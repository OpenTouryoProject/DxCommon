azureBastionRgName=AzureBastionRG
azureBastionVnetName=AzureBastionVnet
yourRgName=YourRG
yourVnetName=YourVnet

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
