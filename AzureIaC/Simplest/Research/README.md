# Simplest（Research）

Azure Bastion、踏み台（Jumpbox）VM、作業用（Sandbox）VM、VNet ピアリングを、最小構成で作る手順の調査。

## ファイル
- [Concept.md](./Concept.md): 調査した手順（Azure CLI / Azure PowerShell のコマンド）。
- `1.common.sh` 〜 `4.vnet_peering.sh`: 手順をシェル スクリプトにしたもの（Azure CLI）。
- [Notes.md](./Notes.md): Tool の作成と、実機での確認で分かったこと（調査メモ）。

## Concept.md の内容
- Azure Bastion の作成
- 踏み台 VM とネットワーク、自動シャットダウン
- 作業用 VM（Sandbox）
- VNet ピアリング

## Tool
同じ手順を Azure PowerShell のスクリプトにしたものが [Tool](../Tool/README.md)（対話メニューつき）。
