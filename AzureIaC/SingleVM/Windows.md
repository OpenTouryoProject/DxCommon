# Single Azure Windows VM

## IaC
This IaC builds single Azure Windows VM.

### Cloud Shell
- [Set environment variables.](./README.md)
- [Resource groups should be created in advance.](./README.md)

- create vm
```Bash
az vm create \
  --resource-group $yourRgName \
  --name $vmName \
  --location $location \
  --size $vmSize \
  --image $vmOS \
  --admin-user $vmUser \
  --admin-password $vmPassword \
  --public-ip-sku Standard \
```

### Reference
- VM起動後の開発環境のセットアップ（Windows） - 開発基盤部会 Wiki
https://dotnetdevelopmentinfrastructure.osscons.jp/index.php?VM%E8%B5%B7%E5%8B%95%E5%BE%8C%E3%81%AE%E9%96%8B%E7%99%BA%E7%92%B0%E5%A2%83%E3%81%AE%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97%EF%BC%88Windows%EF%BC%89
