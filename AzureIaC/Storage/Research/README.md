# Storage

## IaC
This IaC builds Azure Storage.

### Variables

#### Define
```Bash
subscriptionID=$(az account show --query id --output tsv)
userPrincipalName=$(az ad signed-in-user show --query userPrincipalName --output tsv)
location=japaneast #westus2
storageRgName=DxCmnRG
storageAccountName=osscjpdevinfra
containerName=dxcmn
```

#### Check
```Bash
echo $subscriptionID
echo $userPrincipalName
echo $location
echo $storageRgName
echo $storageAccountName
echo $containerName
```

### Creating

```Bash
az group create --name $storageRgName --location $location

az storage account create \
  --name $storageAccountName \
  --resource-group $storageRgName \
  --location $location \
  --sku Standard_LRS

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $userPrincipalName \
  --scope /subscriptions/${subscriptionID}/resourceGroups/${storageRgName}/providers/Microsoft.Storage/storageAccounts/${storageAccountName}

az storage container create \
  --account-name $storageAccountName \
  --name $containerName \
  --auth-mode login
```

Add as needed.
```Bash
az storage account network-rule add \
  --account-name $storageAccountName \
  --resource-group $storageRgName \
  --ip-address xxx.xxx.xxx.xxx

az storage account network-rule list --account-name $storageAccountName
```

### Reference
- Azureのストレージ - マイクロソフト系技術情報 Wiki > IaC化  
https://techinfoofmicrosofttech.osscons.jp/index.php?Azure%E3%81%AE%E3%82%B9%E3%83%88%E3%83%AC%E3%83%BC%E3%82%B8#ea519673
