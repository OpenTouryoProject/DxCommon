## Master AI Agentic Engineering -  build autonomous AI Agents

# PC向けセットアップ手順

ようこそ、PCの皆さん！

AI最前線で作業できる強力な環境を整えるのは、思ったより簡単ではありません。少し大変かもしれません。でも、この手順が完全無欠であることを本当に願っています！

もし問題が発生したら、遠慮せずに連絡してください。すぐに動かせるようにサポートします。「詰まった」と感じるのが一番つらいです。メッセージ、メール、LinkedIn経由で連絡してください。すぐに解決します！

* Email: [ed@edwarddonner.com](mailto:ed@edwarddonner.com)
* LinkedIn: [https://www.linkedin.com/in/eddonner/](https://www.linkedin.com/in/eddonner/)

*もしCursor上でこれを見ている場合は、左側のExplorerでファイル名を右クリックして「プレビューを開く」を選択し、フォーマットされたバージョンを確認してください。*

コマンドプロンプトを比較的最近使い始めた方は、以下の[ガイド](https://chatgpt.com/share/67b0acea-ba38-8012-9c34-7a2541052665)が非常に役立ちます。最初にこれを実践して、自信をつけることをおすすめします。

### はじめる前に — 注意事項

**特記事項**：以下リストの3番目と4番目の項目でつまずく学生が多いです。PCでまだ対応していない場合、後で問題になります😅  — 必ず確認してください。

PCはファイル名260文字以上に対応していること、Microsoft Build Toolsがインストールされていることが必要です。さもないと一部のデータサイエンスパッケージが動作しません。

Windows開発でよくある注意点は4つです：

1. **権限**：Windowsの権限についてはこの[チュートリアル](https://chatgpt.com/share/67b0ae58-d1a8-8012-82ca-74762b0408b0)を確認
2. **アンチウイルス、ファイアウォール、VPN**：インストールやネットワーク接続を妨げる場合があります。必要に応じて一時的に無効化
3. **Windowsのファイル名260文字制限**：詳細な[説明と解決法](https://chatgpt.com/share/67b0afb9-1b60-8012-a9f7-f968a5a910c7)があります。変更後は再起動が必要
4. **データサイエンスパッケージ未使用の場合**：Microsoft Build Toolsをインストールする必要があります。こちらの[手順](https://chatgpt.com/share/67b0b762-327c-8012-b809-b4ec3b9e7be0)を参照。Windows 11の場合、[こちらの手順](https://github.com/bycloudai/InstallVSBuildToolsWindows)も役立つ場合があります

### Part 1: リポジトリのクローン

1. **Gitのインストール**（未インストールの場合）：

* [https://git-scm.com/download/win](https://git-scm.com/download/win) からGitをダウンロード
* インストーラーを実行し、デフォルトオプションで進める（OKを何度も押す！）

2. **コマンドプロンプトを開く**：

* Win + R を押して `cmd` と入力、Enter

3. **プロジェクトフォルダに移動**：

プロジェクト用のフォルダがあれば、`cd` コマンドで移動
例：

```
cd C:\Users\YourUsername\projects
```

`YourUsername`は自分のWindowsユーザー名に置き換える

プロジェクトフォルダがなければ作成：

```
mkdir C:\Users\YourUsername\projects
cd C:\Users\YourUsername\projects
```

4. **リポジトリをクローン**：

プロジェクトフォルダ内でコマンドプロンプトに以下を入力：

```
git clone https://github.com/ed-donner/agents.git
```

これでプロジェクトフォルダ内に `agents` ディレクトリが作成され、クラスのコードがダウンロードされます。

`cd agents` で移動。`agents` は「プロジェクトルートディレクトリ」と呼ばれます。

### Part 2: Cursorのインストール

Cursorは便利ですが、人によって好みが分かれます。AI推奨機能が不安定なこともあります。

学生のAlirezaの指摘通り、VS Codeや他のIDEでも代替可能です。

CursorはVS Codeベースなので、どちらでもコース内容は問題なく動作します。

1. [https://www.cursor.com/](https://www.cursor.com/) にアクセス
2. 右上の Sign In → Sign Up でアカウント作成
3. ダウンロードし、指示に従ってインストール・起動

Cursor起動後はデフォルト設定でOK。

プロジェクトを開く手順：

1. Cursor起動
2. Fileメニュー >> New Window
3. "Open project" をクリック
4. `agents` ディレクトリ（プロジェクトルート）を選択し Open
5. プロジェクト起動時に「Python / Jupyter推奨拡張をインストールしますか？」と出たら Yes

   * 手動の場合：View >> Extensions で python と jupyter を検索し、それぞれインストール

Explorer (View >> Explorer) で各週のフォルダが表示されます。

### Part 3: すごい `uv`

このコースでは、超高速パッケージマネージャ `uv` を使用。データサイエンス界隈で急速に普及中。

高速かつ信頼性抜群です。きっと気に入るはず！

インストール手順（スタンドアロンインストーラー推奨）：
[https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/)

Cursor内で View >> Terminal を選択しターミナルを開く
`pwd` でカレントディレクトリを確認（`agents` ディレクトリになっているか）

まず最新バージョン確認：

```
uv self update
```

注意：Anacondaを以前使用していた場合、環境を無効化：

```
conda deactivate
```

問題が残る場合：

```
conda config --set auto_activate_base false
```

その後：

```
uv sync
```

Python 3.12 と必要なパッケージが自動インストールされます。
証明書エラーが出る場合：

```
uv --native-tls sync
uv --allow-insecure-host github.com sync
```

CrewAI用に必要なツールをインストール：

```
uv tool install crewai
uv tool upgrade crewai
```

確認：

1. プロジェクトルートに `.venv` フォルダがあるか
2. `uv python list` で Python 3.12 が表示されるか
3. `uv tool list` で crewai が表示されるか

uvの使い方：

* `pip install xxx` → `uv add xxx`
* `python my_script.py` → `uv run my_script.py`
* `uv sync` は通常不要
* pyproject.toml や uv.lock の手動編集は避ける
* パッケージ全更新は `uv lock --upgrade`
* ドキュメント: [https://docs.astral.sh/uv/](https://docs.astral.sh/uv/)

### Part 4: OpenAI Key

任意。APIにお金をかけたくない場合は不要。ただし、Agenticシステムの性能を最大化したい場合は推奨。

無料・低コスト代替（OpenRouterやOllama）の利用も可能：[ガイド](../guides/09_ai_apis_and_ollama.ipynb)

OpenAIの場合：

1. [https://platform.openai.com/](https://platform.openai.com/) でアカウント作成
2. 最低\$5のクレジットが必要（USの場合）。API利用分はこのクレジットから消費
3. APIキー作成： [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys) で「Create new secret key」を押す。キーは `sk-proj-` で始まる

AnthropicやGoogle APIも同様に設定可能：

* Claude API: [https://console.anthropic.com/](https://console.anthropic.com/)
* Gemini API: [https://aistudio.google.com/](https://aistudio.google.com/)

コース中に他の低コスト・無料APIも設定します。

### Part 5: `.env` ファイル

APIキー取得後、`.env` ファイルを作成：

1. Cursorで File >> New Text File
2. 以下を入力：

```
OPENAI_API_KEY=取得したキーをここに貼り付け
```

他のキーも追加可能：

```
GOOGLE_API_KEY=xxxx
ANTHROPIC_API_KEY=xxxx
DEEPSEEK_API_KEY=xxxx
```

3. File >> Save As.. で `agents` ディレクトリに `.env` として保存（必ず4文字 `.env`）

編集後は必ず保存！

## 完了！

Cursorで Python / Jupyter 拡張がインストール済みか確認。

左側Explorerで `1_foundations` フォルダを開き、`1_lab1.ipynb` をダブルクリック。

「Select Kernel」で `.venv (Python 3.12.9)` を選択（必要に応じて「Python Environments」をクリック）。

セルを選択し Shift + Enter で実行。

Kernelに `.venv` が表示されない場合：

1. File >> Preferences >> VSCode Settings（Cursor Settingsではない）
2. 検索バーに「venv」
3. 「Path to folder with a list of Virtual Environments」にプロジェクトルートを入力
4. 再試行

問題があれば [troubleshooting.ipynb](troubleshooting.ipynb) を参照

不明点は [ed@edwarddonner.com](mailto:ed@edwarddonner.com) まで連絡してください。
