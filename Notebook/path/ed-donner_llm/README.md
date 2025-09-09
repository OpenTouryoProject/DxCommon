2025/7/22

このフォルダは、以下のリポジトリの内容に

https://github.com/ed-donner/llm_engineering/

以下の翻訳ツールで翻訳したファイル（_ja）を含め

https://github.com/WittmannF/

微調整（≠ファインチューニング）を行ったものです。

- 使用する有償APIをOpneAIのみにした。
- 性能的に修正したりGoogleClabで実行したり。
- GoogleClabの*.ipynbファイルの実体を含めた。
- コードへコメントを付与し内部文書化した。
- その他、実装がより良くなるように修正した。
- EXERCISEについては、contributionsから  
良さそうなものを抜き出して、_jaの内容に含めた。

オリジナルのREADMEは、README_org.mdを見て下さい。

翻訳しただけで、動作確認していないものもあり、  
ソレについては、_jaで内容を確認し、_jaではない方で実行して下さい。

また、一部、Google Clabの実行結果を含むファイルは、
（week3、7は全てClab、week6は一部、Clabで実行）
GitHubのViewer上で「Invalid Notebook」になるようです。
コレの内容については、自身のJupiter環境で確認するか、
Clabの [ノートブックを開く] > [GitHub] からURLを指定して下さい。

なお、community-contributions（extras、solutions）  
などのフォルダは大き過ぎて対象にできませんでした。

以下は解説コンテンツ

LLM Engineering：Master AI、Large Language Models＆Agents - 開発基盤部会 Wiki
https://dotnetdevelopmentinfrastructure.osscons.jp/index.php?LLM%20Engineering%EF%BC%9AMaster%20AI%E3%80%81Large%20Language%20Models%EF%BC%86Agents

環境には、WSL2のUbuntu 24.04 LTS上のPython仮想環境（.xxx_venv）上のJupyter Labを使用。  
`.env`、`requirements.txt`は使用せず、個別の `export`、`pip install`で進めました。