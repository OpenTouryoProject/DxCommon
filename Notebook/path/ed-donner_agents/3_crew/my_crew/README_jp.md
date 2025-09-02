※ このファイルは、`crewai create crew my_crew`コマンドとともに生成される。

# MyCrew Crew

[crewAI](https://crewai.com) によって支えられた **MyCrew Crew プロジェクト** へようこそ。

このテンプレートは、強力で柔軟な crewAI フレームワークを活用し、マルチエージェント AI システムを簡単に構築できるように設計されています。

私たちの目標は、エージェント同士が複雑なタスクに効果的に協力し、その集合知と能力を最大限に活かせるようにすることです。


## インストール

システムに **Python >=3.10 <3.14** がインストールされていることを確認してください。

このプロジェクトは依存関係管理とパッケージ処理に [UV](https://docs.astral.sh/uv/) を使用しており、シームレスなセットアップと実行環境を提供します。

まず、まだインストールしていない場合は uv を導入してください:

```bash
pip install uv
```

次に、プロジェクトディレクトリへ移動し依存関係をインストールします:

（オプション）依存関係をロックして CLI コマンドを使ってインストールする場合:

```bash
crewai install
```

### カスタマイズ

**`.env` ファイルに `OPENAI_API_KEY` を追加してください**

- `src/my_crew/config/agents.yaml` を編集してエージェントを定義
- `src/my_crew/config/tasks.yaml` を編集してタスクを定義
- `src/my_crew/crew.py` を編集して独自のロジック、ツール、引数を追加
- `src/my_crew/main.py` を編集してエージェントやタスクへのカスタム入力を追加

## プロジェクトの実行

AI エージェントのチームを起動し、タスク実行を始めるには、プロジェクトのルートフォルダから以下を実行してください:

```bash
$ crewai run
```

このコマンドは my_crew Crew を初期化し、設定で定義されたエージェントを集め、タスクを割り当てます。

未変更のサンプルでは、LLM に関するリサーチの結果を `report.md` ファイルとしてルートフォルダに出力します。

## Crew の理解

my_crew Crew は複数の AI エージェントで構成され、それぞれに固有の役割、目標、ツールがあります。

これらのエージェントは `config/tasks.yaml` に定義された一連のタスクに協力しながら取り組み、その集合スキルを活かして複雑な目的を達成します。

`config/agents.yaml` では、各エージェントの能力や設定が記載されています。

## サポート

MyCrew Crew または crewAI に関するサポート、質問、フィードバックは以下へどうぞ:

- [ドキュメント](https://docs.crewai.com)
- [GitHub リポジトリ](https://github.com/joaomdmoura/crewai) での連絡
- [Discord コミュニティ](https://discord.com/invite/X4JWnZnxPb) への参加
- [ドキュメントとのチャット](https://chatg.pt/DWjSBZn)

crewAI の力とシンプルさで、一緒に驚きを生み出しましょう。
