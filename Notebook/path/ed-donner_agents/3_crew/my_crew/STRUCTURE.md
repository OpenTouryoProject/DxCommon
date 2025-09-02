
```
$ tree my_crew/
my_crew/
├── README.md
├── README_jp.md
├── knowledge
│   └── user_preference.txt
├── pyproject.toml
├── src
│   └── my_crew
│       ├── __init__.py
│       ├── config
│       │   ├── agents.yaml
│       │   └── tasks.yaml
│       ├── crew.py
│       ├── main.py
│       └── tools
│           ├── __init__.py
│           └── custom_tool.py
└── tests
```

## プロジェクトルート

* **.env、.gitignore**
  .env環境変数ファイルは.gitignore除外ファイルで追加されないが、  
  実行の際に必要になり中には一行 `MODEL=gpt-4o-mini` が定義されていた。

* **README.md**
  プロジェクトの説明文。

  * `README.md` : 英語版

* **pyproject.toml**
  Python プロジェクトの依存関係や設定を定義するファイル。

  * `crewai` や `openai` など、必要なライブラリがここに書かれる。
  * Poetry や uv などの依存管理ツールで利用される。

* **knowledge**

  * **user\_preference.txt**
    知識ベースやユーザの嗜好を記録するファイル。
    RAG の簡易知識ベースとして活用可能。

* **tests**
  ユニットテスト用ディレクトリ。
  `pytest` などでテストを書き、エージェントやツールが期待通り動作するか確認する。

## src/my_crew 配下

実際のアプリケーションコードはここにまとまる。

* **__init__.py**
  Python パッケージとして認識させるためのファイル。

* **config**
  設定ファイルを管理するディレクトリ。YAML 形式でエージェントやタスクを定義する。

  * **agents.yaml**
    エージェントの一覧。
    例：役割、人格、使用する LLM モデルなどを定義。
  * **tasks.yaml**
    タスクの一覧。
    例：エージェント同士の協力関係、実行手順、ゴールの定義。

* **crew.py**
  エージェント（agents.yaml）とタスク（tasks.yaml）を読み込み、Crew（チーム）を組み立てる処理。
  CrewAI の中核部分。

* **main.py**
  プロジェクトのエントリーポイント。
  `python src/my_crew/main.py` でチームを起動できる。

* **tools**
  エージェントが外部の機能を使うためのカスタムツールを定義する場所。

  * ****init**.py** : パッケージ管理用。
  * **custom\_tool.py** : ユーザーが自作のツールを追加するサンプル。API呼び出しや外部DBアクセスなどを実装可能。

## **まとめると**

- **config/** : エージェントやタスクの定義（宣言的設定）
- **crew.py** : それらを読み込んでチームを構築
- **main.py** : 実行エントリーポイント
- **tools/** : 外部機能を追加する場所
- **knowledge/** : 知識ベース的な補助情報
- **tests/** : 動作検証
