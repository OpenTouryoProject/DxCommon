2025/8/25

このフォルダは、以下のリポジトリの内容に

https://github.com/ed-donner/agents/

以下の翻訳ツールで翻訳したファイル（_ja）を含め

https://github.com/WittmannF/

微調整（≠ファインチューニング）を行ったものです。

- 使用するAPIを有償のOpneAIと無償のGeminiにした。
- 性能的に修正したりGoogleClabで実行したり。
- GoogleClabの*.ipynbファイルの実体を含めた。
- コードへコメントを付与し内部文書化した。
- その他、実装がより良くなるように修正した。
- EXERCISEについては、contributionsから  
良さそうなものを抜き出して、_jaの内容に含めた。

オリジナルのREADMEは、README_org.mdを見て下さい。

翻訳しただけで、動作確認していないものもあり、  
ソレについては、_jaで内容を確認し、_jaではない方で実行して下さい。

なお、community-contributions（extras、solutions）  
などのフォルダは大き過ぎて対象にできませんでした。

以下は解説コンテンツ

The Complete Agentic AI Engineering Course (2025) - 開発基盤部会 Wiki
https://dotnetdevelopmentinfrastructure.osscons.jp/index.php?The%20Complete%20Agentic%20AI%20Engineering%20Course%20%282025%29

環境には、Windows上の VS Code → WSL2(Ubuntu 24.04 LTS)上のPython仮想環境（.xxx_venv）＋必要に応じてJupyter Labを使用。  
`.env` を使用、`requirements.txt`も、依存関係の多そうな一部のプロジェクトで使用（`4_langgraph`, `5_autogen`）

また、一部のプロジェクトで（`3_crew`, ...）ではuvが前提となっているため、uvと、その配下の仮想環境（.venv）を使用。
- uvの仮想環境は、`ed-donner_agents` フォルダで `uv sync` コマンドを実行すると、`uv.lock`に基づき`.venv`フォルダが作成される。
- 当該フォルダ以下のフォルダで、`uv ～` コマンドを使用する場合、作成した仮想環境が自動検出され使用される設計になっている。