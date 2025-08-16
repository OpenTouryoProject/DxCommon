import os
import sys
import logging
import json
from typing import List, Optional
#from twilio.rest import Client
from dotenv import load_dotenv
import chromadb
from agents.planning_agent import PlanningAgent
from agents.deals import Opportunity
from sklearn.manifold import TSNE
import numpy as np

# Colors for logging
# ログの色（ANSI カラーコード）
BG_BLUE = '\033[44m'
WHITE = '\033[37m'
RESET = '\033[0m'

# Colors for plot
# （3D）プロットの色
CATEGORIES = ['Appliances', 'Automotive', 'Cell_Phones_and_Accessories', 'Electronics','Musical_Instruments', 'Office_Products', 'Tools_and_Home_Improvement', 'Toys_and_Games']
COLORS = ['red', 'blue', 'brown', 'orange', 'yellow', 'green' , 'purple', 'cyan']

# ログ初期化関数
def init_logging():
    
    root = logging.getLogger()

    # ルートの設定
    root.setLevel(logging.INFO)

    # 標準出力ハンドラと、その設定
    handler = logging.StreamHandler(sys.stdout)
    # INFO レベル以上を出力
    handler.setLevel(logging.INFO)
    # フォーマットは [日時] [Agents] [レベル] メッセージ。
    handler.setFormatter(logging.Formatter(
        "[%(asctime)s] [Agents] [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S %z",
        ))

    # ハンドラをルートに設定
    root.addHandler(handler)

# 取引エージェント実行フレームワーク
class DealAgentFramework:

    # RAGのVDB名
    DB = "products_vectorstore"
    # メモリファイル名
    MEMORY_FILENAME = "memory.json"

    # 初期化
    def __init__(self):
        # ログの初期化
        init_logging()
        # 変数読込
        load_dotenv()
        # VDB接続
        client = chromadb.PersistentClient(path=self.DB)
        self.collection = client.get_or_create_collection('products')
        # メモリファイル読込
        self.memory = self.read_memory()
        # 計画エージェント未設定
        self.planner = None

    # 計画エージェントの初期化
    def init_agents_as_needed(self):
        if not self.planner: # 未設定の場合に設定
            self.log("Initializing Agent Framework")
            self.planner = PlanningAgent(self.collection)
            self.log("Agent Framework is ready")
    
    # メモリファイル読込
    # memory.json を読込、Opportunities に変換
    def read_memory(self) -> List[Opportunity]:
        # ファイルから list[dict] を読込 Opportunity(**item) でOpportunities化
        if os.path.exists(self.MEMORY_FILENAME):
            with open(self.MEMORY_FILENAME, "r") as file:
                data = json.load(file)
            opportunities = [Opportunity(**item) for item in data]
            return opportunities
        return []

    # メモリファイル書込
    # self.memory(Opportunities) の各 Opportunity を辞書化してJSON保存。
    def write_memory(self) -> None:
        # list[Opportunity.dict()] で list[dict] に変換してファイルに書込
        data = [opportunity.dict() for opportunity in self.memory]
        with open(self.MEMORY_FILENAME, "w") as file:
            json.dump(data, file, indent=2)

    # ログ出力
    def log(self, message: str):
        text = BG_BLUE + WHITE + "[Agent Framework] " + message + RESET
        logging.info(text)

    # 計画エージェントのワークフローを実行
    def run(self) -> List[Opportunity]:
        self.init_agents_as_needed()

        # 計画エージェントのワークフローを実行
        logging.info("Kicking off Planning Agent")

        # 計画エージェントのワークフローを実行
        result = self.planner.plan(memory=self.memory)

        # 計画エージェントが完了し、次の結果を返し: {result}
        logging.info(f"Planning Agent has completed and returned: {result}")
        
        if result: # Opportunity
            # メモリに保存
            self.memory.append(result)
            # メモリファイルに保存
            self.write_memory()

        # Opportunities
        return self.memory

    # 3Dプロット
    @classmethod
    def get_plot_data(cls, max_datapoints=10000):
        client = chromadb.PersistentClient(path=cls.DB)
        collection = client.get_or_create_collection('products')
        result = collection.get(include=['embeddings', 'documents', 'metadatas'], limit=max_datapoints)
        vectors = np.array(result['embeddings'])
        documents = result['documents']
        categories = [metadata['category'] for metadata in result['metadatas']]
        colors = [COLORS[CATEGORIES.index(c)] for c in categories]
        tsne = TSNE(n_components=3, random_state=42, n_jobs=-1)
        reduced_vectors = tsne.fit_transform(vectors)
        return documents, reduced_vectors, colors

# スクリプトとして直接実行された場合
# 計画エージェントのワークフローを実行
if __name__=="__main__":
    DealAgentFramework().run()
    