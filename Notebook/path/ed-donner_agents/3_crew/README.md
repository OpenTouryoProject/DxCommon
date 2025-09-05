# Day0：my_crew
`uv` と `crewai` の環境を整えるため、`setup` フォルダや `README` の内容から以下を実行

※ `uv` は `install.sh ` を使用してインストール済みであること。  
※ コレ等のコマンドは、`ed-donner_agents`フォルダで実行する。

```bash
uv self update
uv sync
uv tool install crewai
uv tool upgrade crewai

crewai install
```

次に、`3_crew`フォルダでcrewai create crew my_crew`コマンドを実行して

- LLMプロバイダを選択：OpenAI
- LLMのモデルIDを選択：gpt-4o-mini
- APIキーを設定（スキップ可能）

プロジェクトを生成し、主に、非機能面（構成、アーキテクチャ）の確認を行う。

プロジェクトの実行は、カレント・ディレクトリで、以下を実行

```bash
$ crewai run
```
# Day0.5：jp_crew
コレは、同様に`crewai create crew jp_crew`コマンドを実行して生成されたプロジェクトで、

主に、機能面（インストラクションとレポート）の確認を行うため、内容を日本語化＋コメント追加した。

# Day1：1_debate
コレは、講師が`crewai create crew debatew`コマンドを実行して作成したプロジェクトで、

「ディベート」機能に書き直されている。内容は日本語化＋コメント追加してある。

`.env` は、本コースの前半で、`path` フォルダ直下に配置したモノを使うので不要。  
（利用LLMは `agents.yaml` に直下書き、APIキーは、OPENAI_API_KEY, GOOGLE_API_KEY を使用）

# Day2：2_financial_researcher
コレは、講師が`crewai create crew financial_researcher`コマンドを実行して作成したプロジェクトで、

「金融調査員」機能に書き直されている。内容は日本語化＋コメント追加してある。

機能的な追加は以下の2点だが、
- researcherが、SerperDevToolを使用
- analysis_task で context に research_task を指定し調査結果を参照

後者は既定で引き継がれており不要のためコメントアウト。

# Day3：3_stock_picker
コレは、講師が`crewai create crew stock_picker`コマンドを実行して作成したプロジェクトで、

「銘柄選択投資」機能に書き直されている。内容は日本語化＋コメント追加してある。

機能的な追加は以下の4, 5点
- 各種エージェントが、構造化出力を使用
- プッシュ通知の送信カスタム・ツールを使用
- ヒエラルキー実行モードでコンテキストを使用して情報を受け渡す。
- 短期 / 長期 / エンティティ・メモリを使用するよう設定。

# Day4：4_coder
コレは、講師が`crewai create crew coder`コマンドを実行して作成したプロジェクトで、

「コーダー・エージェント」機能に書き直されている。内容は日本語化＋コメント追加してある。

コーディングしたコードを安全に実行するためにDockerを使用する。

以下は、WSL2内のUbuntu 24.04 LTSにDockerをインストールした手順  
（コード内にDocker Desktopとあるが、Docker Desktopである必要はない）

1. **古いバージョンの削除（任意）**
   ```bash
   sudo apt-get remove docker docker-engine docker.io containerd runc
   ```

2. **必要なパッケージをインストール**
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl gnupg lsb-release
   ```

3. **Docker の公式 GPG キーを追加**
   ```bash
   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   ```

4. **APT リポジトリを追加**
   ```bash
   echo \
     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```

5. **Docker Engine をインストール**
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

6. **インストール確認**
   ```bash
   sudo docker run hello-world
   ```
   → "Hello from Docker!" が出れば成功です。

7. **sudo なしで Docker を使えるようにする**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   docker run hello-world
   ```

# Day5：engineering_team
講師が`crewai create crew engineering_team`コマンドを実行して作成したプロジェクトで、

「エンジニア・チーム」機能に書き直されている。内容は日本語化＋コメント追加してある。

特に新しい機能は使用されていないが、以下の特徴を持つ。

- 2_financial_researcherと同様に、context を使用。シーケンシャルだが次の次のエージェントに渡すため必須。
- 3_stock_pickerの`3 * 3`より多い`4 * 4`のエージェント * タスクを使用する複雑なエージェント・チーム。
- 4_coderと同様に、Dockerを使ったコード実行機能を使用している。

ちなみに、生成されたアプリは `output`フォルダ に移動し `uv run app.py` と実行する。

以下は、生成したままでは問題が在った部分を修正した際のコミットログ。  
https://github.com/OpenTouryoProject/DxCommon/commit/24d2c7d2bb2582da8ac1435ca34c12463bcdd139
