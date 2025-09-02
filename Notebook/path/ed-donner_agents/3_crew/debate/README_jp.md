# Debate Crew

Debate Crewプロジェクトへようこそ。本プロジェクトは [crewAI](https://crewai.com) によって動作しています。

このテンプレートは、強力で柔軟な **crewAI フレームワーク** を活用し、マルチエージェントAIシステムを簡単に構築できるように設計されています。

私たちの目標は、エージェントたちが複雑なタスクで効果的に協力し、集団的な知能と能力を最大化することです。

## インストール

システムに **Python >=3.10 <3.13** がインストールされていることを確認してください。

```bash
python --version
```

このプロジェクトでは [UV](https://docs.astral.sh/uv/) を使用して依存関係管理とパッケージ処理を行い、スムーズなセットアップと実行を提供します。

まず、まだインストールしていない場合は uv を導入します：

（ネイティブバイナリ版の uvではなく、PyPI 上に公開されている uv パッケージをインストール）

```bash
pip install uv
```

次に、プロジェクト・ディレクトリへ移動して依存関係をインストールしてください：

（オプション）依存関係をロックして CLI コマンドを使用してインストールするには：

```bash
crewai install

```

### カスタマイズ

**`.env` ファイルに `OPENAI_API_KEY` を追加してください**

* `src/debate/config/agents.yaml` を編集してエージェントを定義
* `src/debate/config/tasks.yaml` を編集してタスクを定義
* `src/debate/crew.py` を編集して独自のロジック、ツール、引数を追加
* `src/debate/main.py` を編集してエージェントやタスク用のカスタム入力を追加

## プロジェクトの実行

AIエージェントのチームを起動し、タスク実行を開始するには、プロジェクトのルートフォルダから以下を実行してください：

```bash
$ crewai run
```

このコマンドは Debate Crew を初期化し、設定ファイルで定義された通りにエージェントを組み立て、タスクを割り当てます。

そのまま実行すると、ルートフォルダに **`report.md`** が生成され、LLMに関するリサーチ結果が出力されます。

## Crew の理解

Debate Crew は複数の AI エージェントで構成され、それぞれ固有の役割・目標・ツールを持ちます。

エージェントたちは `config/tasks.yaml` で定義された一連のタスクに協力して取り組み、集団的なスキルを活かして複雑な目的を達成します。

各エージェントの能力や設定は `config/agents.yaml` に記載されています。

## サポート

Debate Crew や crewAI に関するサポート・質問・フィードバックはこちらから：

- [ドキュメント](https://docs.crewai.com)
- [GitHub リポジトリ](https://github.com/joaomdmoura/crewai)
- [Discord 参加](https://discord.com/invite/X4JWnZnxPb)
- [ドキュメントとのチャット](https://chatg.pt/DWjSBZn)

crewAI の **力とシンプルさ** を活かして、共に素晴らしいものを創りましょう。
