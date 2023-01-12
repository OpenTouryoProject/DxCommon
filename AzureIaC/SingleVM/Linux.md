# Single Azure Linux VM

## IaC
This IaC builds single Azure Linux VM.

### Cloud Shell
- [Set environment variables.](./README.md)
- [Resource groups should be created in advance.](./README.md)

- create sshkey
```Bash
ssh-keygen -m PEM -t rsa -b 4096 -f hoge

az sshkey create \
  --resource-group $yourRgName \
  --name hoge-sshkey \
  --public-key @hoge.pub
```

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
  --ssh-key-name hoge-sshkey \
  --nsg-rule NONE

az network nsg rule create \
  --resource-group $yourRgName \
  --name Allow-SSH \
  --nsg-name ${vmName}NSG \
  --priority 100 \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp
```

### WSL2
- Download hoge file from Cloud Shell.
- [Set environment variables.](./README.md)

#### ssh
```Bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login

ssh -i /mnt/.../hoge ${vmUser}@$(az vm show \
  --resource-group $yourRgName \
  --name $vmName \
  --show-detail \
  --query publicIps \
  --output tsv)
```

#### xrdp


```Bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install xfce4
sudo apt install xfce4-session

sudo apt-get -y install xrdp
sudo systemctl enable xrdp

sudo adduser xrdp ssl-cert

echo xfce4-session >~/.xsession

sudo service xrdp restart
```

### Cloud Shell

#### open rdp port

```Bash
az vm open-port --resource-group $yourRgName --name $vmName --port 3389
```

### RDP

#### Locale

- timezone
```Bash
sudo timedatectl set-timezone Asia/Tokyo
```

- language and fonts
```Bash
sudo apt install -y language-pack-ja-base language-pack-ja ibus-mozc fonts-takao-pgothic fonts-takao-gothic fonts-takao-mincho
sudo localectl set-locale LANG=ja_JP.UTF-8 LANGUAGE="ja_JP:ja"
source /etc/default/locale
```

- keyboard
  - Generic 105-key PC (Intl.)
  - 日本語
  - 日本語
  - キーボード配置のデフォルト
  - コンポーズキーなし
  - いいえ
```Bash
sudo dpkg-reconfigure keyboard-configuration
```

#### Web Browser
```Bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb
google-chrome
```