# Single Azure VM

## IaC
This IaC builds single Azure VM.

### Variables


#### Define1
```Bash
location=japaneast
yourRgName=hogeRG
vmName=hogeVM
vmUser=[...]
vmPassword=[...]
```

#### Define2
```Bash
az vm list-sizes --location $location --output table
az vm image list --location $location --output table
```

```Bash
vmSize=Standard_A8_v2
vmOS=UbuntuLTS or Win20..
```

#### Check
```Bash
echo $location
echo $yourRgName
echo $vmSize
echo $vmOS
echo $vmName
```

### Creating

#### RG
```Bash
az group create --name $yourRgName --location $location
```

#### VM

- [Windows](./Windows.md)
- [Linux](./Linux.md)
