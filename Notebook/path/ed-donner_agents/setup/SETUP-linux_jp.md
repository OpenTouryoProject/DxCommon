## Master AI Agentic Engineering - 自律型AIエージェントの構築

# Linux用セットアップ手順

Linuxの皆さん、ようこそ！

最先端のAI環境を構築するのは、思ったより簡単ではありません。

少し手間がかかります。でも、この手順書が完璧であることを願っています！

もし問題が発生した場合は、遠慮なく連絡してください。迅速にサポートします。

「詰まった」と感じるのは最悪です。メッセージ、メール、LinkedInいずれでも連絡してください。すぐに解決します！

メール: [ed@edwarddonner.com](mailto:ed@edwarddonner.com)
LinkedIn: [https://www.linkedin.com/in/eddonner/](https://www.linkedin.com/in/eddonner/)

*Cursorで見ている場合は、左のExplorerでファイル名を右クリックし、「Open Preview」を選択するとフォーマット済みの表示になります。*

### はじめる前に

注意点：「アンチウイルスソフト、VPN、ファイアウォール」を使っている場合、インストールやネットワークアクセスに干渉する可能性があります。問題が発生した場合は、一時的に無効化してください。

### Part 1: リポジトリのクローン

ローカルマシンにコードをコピーします。

1. **Gitをインストール**（未インストールの場合）:

* ターミナルを開く
* `git --version` を実行。Gitがない場合は、ディストリビューションに応じて以下を実行：

  * Debian/Ubuntu: `sudo apt update && sudo apt install git`
  * Fedora: `sudo dnf install git`
  * Arch: `sudo pacman -S git`

2. **プロジェクトフォルダに移動**:

`cd` コマンドでプロジェクト用フォルダに移動します。例:
`cd ~/projects`

フォルダがない場合は作成：

```bash
mkdir ~/projects
cd ~/projects
```

3. **リポジトリをクローン**:

```bash
git clone https://github.com/ed-donner/agents.git
```

`agents` というディレクトリが作成され、コースのコードがダウンロードされます。
`cd agents` でディレクトリに移動。これが「プロジェクトルートディレクトリ」です。

### Part 2: Cursorのインストール

Cursorは便利なツールですが、好みが分かれます。AI推奨機能が不安定になることもあります。

希望すればVS Codeや他のIDEでも代替可能です。

Cursor自体はVS Codeベースなので、このコースの内容はどちらでも問題ありません。

1. [https://www.cursor.com/](https://www.cursor.com/) にアクセス
2. 右上の「Sign In」→「Sign Up」でアカウント作成
3. ダウンロードしてインストール・起動

Linuxユーザー向けの注意点（学生Ernstの情報）:

インストールは少し複雑です。参考リソース：

* [https://forum.cursor.com/t/can-you-add-a-how-to-guide-on-installing-using-cursor-in-ubuntu/16646/2](https://forum.cursor.com/t/can-you-add-a-how-to-guide-on-installing-using-cursor-in-ubuntu/16646/2)
  → 動画の最初の4分を見る
* [https://github.com/OpenShot/openshot-qt/issues/4789](https://github.com/OpenShot/openshot-qt/issues/4789)
  → AppImageやFuse関連の問題があり、libfuse2のインストールが必要になることがあります

Ubuntu 22.04では問題ありませんが、Ubuntu 24.xではFuse関連の深刻なグラフィック問題が報告されています。新しいライブラリをインストールする前にブログを確認してください。

Cursorを起動したら、質問にはすべてデフォルトで構いません。

プロジェクトを開く手順：

1. Cursorを起動
2. File >> New Window
3. 「Open project」をクリック
4. `agents` ディレクトリを選択してOpen
5. PythonやJupyterの推奨拡張をインストールするように求められたら「Yes」

手動での拡張インストール：

* View >> Extensions
* python検索 → Microsoft製をインストール
* jupyter検索 → Microsoft製をインストール

Explorerを開くと（View >> Explorer）、左に各週のフォルダが表示されます。

### Part 3: すごい `uv`

このコースでは高速パッケージマネージャ `uv` を使用します。Data Science界で急速に普及中です。

高速で信頼性があります。きっと気に入るはず！

インストール手順（Standalone Installer推奨）：
[https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/)

Cursor内で View >> Terminal を開き、ターミナルで現在のディレクトリを確認：

```bash
pwd
```

`agents` ディレクトリにいることを確認。

まず最新バージョンに更新：

```bash
uv self update
```

Anacondaを使ったことがある場合：

```bash
conda deactivate
conda config --set auto_activate_base false
```

その後：

```bash
uv sync
```

証明書エラーが出た場合：

```bash
uv --native-tls sync
uv --allow-insecure-host github.com sync
```

CrewAIの準備：

```bash
uv tool install crewai
uv tool upgrade crewai
```

セットアップ確認：

1. プロジェクトルートに `.venv` フォルダがある
2. `uv python list` で Python 3.12 が表示される
3. `uv tool list` で crewai が表示される

uvの使い方：

* `pip install xxx` → `uv add xxx`
* `python my_script.py` → `uv run my_script.py`
* pyproject.tomlを直接編集しない
* パッケージ更新：`uv lock --upgrade`
* ドキュメント：[https://docs.astral.sh/uv/](https://docs.astral.sh/uv/)

### Part 4: OpenAIキー（任意）

API利用料を避けたい場合はスキップ可能ですが、性能向上のため推奨です。

無料・安価な代替（OpenRouterなど）の情報はこちら：
[09\_ai\_apis\_and\_ollama.ipynb](../guides/09_ai_apis_and_ollama.ipynb)

OpenAIの場合：

1. アカウント作成：[https://platform.openai.com/](https://platform.openai.com/)
2. 最低\$5のクレジットが必要
3. APIキー作成：[https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
   緑の「Create new secret key」を押す
   APIキーは安全な場所に保管

AnthropicやGoogle APIも設定可能：

* Claude API: [https://console.anthropic.com/](https://console.anthropic.com/)
* Gemini API: [https://aistudio.google.com/](https://aistudio.google.com/)

### Part 5: `.env` ファイル

1. Cursorで File >> New Text File
2. 以下を入力：

```text
OPENAI_API_KEY=<ここにOpenAIキー>
```

3. 他のキーも追加可能：

```text
GOOGLE_API_KEY=xxxx
ANTHROPIC_API_KEY=xxxx
DEEPSEEK_API_KEY=xxxx
```

4. File >> Save As.. で `agents` フォルダに `.env` として保存

**注意**: ファイル名は正確に `.env` にしてください。

## これで完了！

Cursorで Python と Jupyter 拡張を確認後、`1_foundations` フォルダ内の `1_lab1.ipynb` を開きます。

右上の「Select Kernel」から `.venv (Python 3.12.9)` を選択し、最初のセルで Shift + Enter を押して実行。

Kernelが表示されない場合：

1. Cursorメニューから Settings >> VSCode Settings
2. 検索バーで `venv` を入力
3. 「Path to folder with a list of Virtual Environments」にプロジェクトルートパスを指定
4. 再試行

問題があれば [troubleshooting.ipynb](troubleshooting.ipynb) を参照、または [ed@edwarddonner.com](mailto:ed@edwarddonner.com) まで連絡してください。
