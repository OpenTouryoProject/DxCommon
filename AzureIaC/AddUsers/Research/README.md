# AddUsers（Research）

Azure に、ユーザーを追加して、ロールで権限を与える手順の調査。

## ファイル
- [Concept.md](./Concept.md): 調査した手順（Azure CLI / Azure PowerShell のコマンド）。
- [Notes.md](./Notes.md): Tool の作成と、実機での確認で分かったこと（調査メモ）。

## Concept.md の内容
- カスタム ロールの作成
- ユーザーの招待
- ロールでの権限付与（リソース グループ / サブスクリプション）
- Cloud Shell での確認と VM の作成

## Tool
同じ手順を Azure PowerShell のスクリプトにしたものが [Tool](../Tool/README.md)（対話メニューつき）。
