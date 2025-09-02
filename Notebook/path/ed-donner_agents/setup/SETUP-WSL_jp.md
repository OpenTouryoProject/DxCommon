## Master AI Agentic Engineering  - 自律型 AI エージェントの構築

# WSL のセットアップ - Windows Subsystem for Linux

_注1: この手順は、すでに PC セットアップ手順を完了していることを前提としています。_

_注2: Cursor を使う場合、このファイルをエクスプローラーで右クリックして「プレビューを開く」を選択すると、フォーマットが正しく表示されます。_

PC の皆さん、セットアップ・ランドへようこそ！

ここに来たのは、Week 6 に到達して、MCP サーバーが WSL 上の Windows でしか動作しないという残念なニュースを知ったからだと思います。

お手数をおかけしてすみません！良いニュースとしては、複数の学生が WSL 上で MCP サーバーが動作することを確認しています。

また、WSL は Windows 上で開発するための優れた方法と一般的に考えられています。

さらに良いニュースとして、あなたはすでに一度セットアップを行っているので、今回も比較的スムーズに進むはずです。指を交差させて…！

### パート 1: WSL をまだインストールしていない場合

WSL は、Windows PC 上で Linux を実行するために Microsoft が推奨する方法です。詳細はこちら：
[https://learn.microsoft.com/en-us/windows/wsl/install](https://learn.microsoft.com/en-us/windows/wsl/install)

今回は、デフォルトの Ubuntu ディストリビューションを使用します。これで問題なく動作するようです。さあ、始めましょう！

1. PowerShell を開く
2. 次を実行: `wsl --install`
3. 権限昇格を許可するか聞かれたら許可し、Ubuntu のインストールが完了するまで待つ
4. 次に `wsl` を実行して起動し、Linux のユーザー名とパスワードを設定
5. `pwd` と `ls` を入力して現在のディレクトリと内容を確認。その後 `cd` を使ってホームディレクトリに移動し、再度確認

Windows のホームディレクトリと、WSL 上の新しい Linux ホームディレクトリの違いを理解することが重要です。

### パート 2: uv とリポジトリのインストール

1. PowerShell から `ubuntu` を実行 - ここで `wsl` ではなく `ubuntu` を実行することが重要です。Linux ホームディレクトリから開始されます
2. 次に Linux の指示に従う: [https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/) で `curl -LsSf https://astral.sh/uv/install.sh | sh` を実行
3. インストール完了後、WSL を終了するために `exit` を入力して PowerShell に戻り、再度 `ubuntu` を実行して Linux に戻る（PATH の変更を反映させるため）
4. `pwd` を入力して Linux ホームディレクトリにいることを確認。不安な場合は `cd ~` で移動し、`ls` で確認
5. 次に `mkdir projects` で projects ディレクトリを作成し、`cd projects` で移動
6. 新しい projects ディレクトリ内で、`git clone https://github.com/ed-donner/agents.git` を実行してリポジトリをクローン
7. `cd agents` で新しい agents ディレクトリ（プロジェクトのルートディレクトリ）に移動
8. 最後に全能の `uv sync` を実行

ここで、私はメモリエラーが発生しました。これは私の環境に起因するものと思われ、通常は発生しないはずです。もし発生した場合はお知らせください。修正方法があります。

### パート 3: PC 環境で Cursor を設定

1. 通常通り、PC で Cursor を開く
2. 拡張機能パネルを開く（View メニュー >> Extensions または Ctrl+Shift+X）、WSL を検索し、Anysphere（Cursor の開発元）の WSL をインストール
3. Ctrl+Shift+P を押して「Remote-WSL: New Window」を検索・選択し、WSL 用に構成された新しいウィンドウを開く
4. 「Open Project」を選択（その間にコーヒーでもどうぞ）、Linux 上の新しい "agents" プロジェクトルートディレクトリに移動して「Open」または「Select Folder」
5. 再度拡張機能パネル（Ctrl+Shift+X）を開き、WSL にまだインストールされていなければ以下をインストール：Python (ms-python)、Jupyter (microsoft)。「Install in WSL-Ubuntu」ボタンをクリック

### これで準備完了です！

agents フォルダ内に新しい `.env` ファイルを作成し、他のプロジェクトから `.env` をコピーしてください。また「Select Kernel」をクリックして「Choose python environment..」を選択する必要があります。

MCP を楽しんでください！
