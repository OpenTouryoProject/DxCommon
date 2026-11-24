# SingleVM（Research）

1 台の Azure VM（Windows / Linux）を作る手順の調査。

## ファイル
- [Concept.md](./Concept.md): 調査した手順（Azure CLI / Azure PowerShell のコマンド）。
- [Windows.md](./Windows.md) / [Linux.md](./Linux.md): OS ごとの VM の作成手順。
- [Notes.md](./Notes.md): Tool の作成と、実機での確認で分かったこと（調査メモ）。

## Concept.md の内容
- 変数（場所、サイズ、イメージ）
- RG と VM の作成（[Windows](./Windows.md) / [Linux](./Linux.md)）

## Tool
同じ手順を Azure PowerShell のスクリプトにしたものが [Tool](../Tool/README.md)（対話メニューつき）。
