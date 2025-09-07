# NodeJSとPlaywrightの追加設定の詳細

_Notebook系で開く場合、右クリックのコンテキスト・メニューからフォーマットされた状態で表示させることができます。または、GitHub でオンライン・バージョンを確認してください。_

第 4 週と第 6 週では、お使いのコンピューターで Node.js を使用します。

PC ユーザーの方へ：WSL を使用している場合（第 6 週で必要になります）、

その時点で Ubuntu 側に Node.js を再度インストールする必要があります。

## Nodeのインストール手順

Nodeがインストールされているかどうかを確認します - v22 以降である必要があります。
`!node --version` 

AI の友人が提供してくれた、非常にわかりやすいインストール手順は次のとおりです。

https://chatgpt.com/share/68103af2-e2dc-8012-b259-bc135a23273b

ほとんどの場合、https://nodejs.org にアクセスして指示に従うだけで済みます。WSL を使用している PC ユーザーの場合は、Linux の指示に従ってください。

完了したら、Notebook系で動作することを確認してください。Cursorを終了して再起動する必要がある場合があります（Cursorで開いているターミナルもすべて閉じてください）。

`!node --version`  
`!npx --version`

## Playwrightのインストール

Playwright は、第 4 週と第 6 週で使用する Microsoft のブラウザー自動化ソフトウェアです。

- On Mac / PC:  
`uv run playwright install`

- On Linux / WSL:  
`uv run playwright install --with-deps chromium`

## トラブルシューティング - Nodeベースの MCP サーバーが Windows / WSL でハングする場合

一部のWSLユーザーにおいて、npxベースのMCPサーバーの実行中にハングアップする問題が発生しているようです。修正方法はこちらです！

まず、Cursorを終了して再起動し、Node.jsのインストール以降の変更を反映させます。また、Cursorで開いているターミナルをすべて終了し、新しいターミナルを開いてください。

ターミナルで次のコマンドを実行します:  
`which node`

これにより、WSLサブシステムで実行されているノードへのパスが取得されます。例えば、次のようなパスだとします。:  
`/home/user/.nvm/versions/node/v22.18.0/bin`

次に、このコマンドを実行し、パスを実際のパスに置き換えてください。:   
`!export PATH="/home/user/.nvm/versions/node/v22.18.0/bin:$PATH"`  

これも、パスを慎重に置き換えてください:  
`os.environ["PATH"] = "/home/user/.nvm/versions/node/v22.18.0/bin:" + os.environ["PATH"]`

そして、前のセルをもう一度試してください。  
それでも上手く行かない場合は、MCPパラメータをnpxのフルパスに変更してみてください。:

```python
playwright_params = {"command": "/home/user/.nvm/versions/node/v22.18.0/bin/npx","args": [ "@playwright/mcp@latest"]}
```

そして/またはこのアプローチ:

```python
env = {"PATH": "/home/user/.nvm/versions/node/v22.18.0/bin:" + os.environ["PATH"]}
playwright_params = {"command": "npx","args": [ "@playwright/mcp@latest"], "env": env}
```

それでも解決しない場合はお知らせください！この問題に取り組み、解決策を見つけて共有してくれたRadoslav R.さんとAndré R.さんに心から感謝します！