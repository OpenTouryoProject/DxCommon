from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task
from crewai_tools import SerperDevTool
from pydantic import BaseModel, Field
from typing import List
from .tools.push_tool import PushNotificationTool
from crewai.memory import LongTermMemory, ShortTermMemory, EntityMemory
from crewai.memory.storage.rag_storage import RAGStorage
from crewai.memory.storage.ltm_sqlite_storage import LTMSQLiteStorage

# 構造化出力のスキーマを定義

# トレンド企業
class TrendingCompany(BaseModel):
    """ ニュースで注目を集めている企業 """
    name: str = Field(description="会社名")
    ticker: str = Field(description="株式銘柄コード")
    reason: str = Field(description="この企業がニュースで注目されている理由")

# トレンド企業リスト
class TrendingCompanyList(BaseModel):
    """ ニュースで注目を集めている複数のトレンド企業リスト """
    companies: List[TrendingCompany] = Field(description="ニュースで注目されている企業リスト")

# トレンド企業の詳細分析
class TrendingCompanyResearch(BaseModel):
    """ 企業の詳細な分析 """
    name: str = Field(description="会社名")
    market_position: str = Field(description="市場における位置付けと競合分析")
    future_outlook: str = Field(description="将来の展望と成長の可能性")
    investment_potential: str = Field(description="投資の可能性と適合性")

# トレンド企業の詳細分析リスト
class TrendingCompanyResearchList(BaseModel):
    """ すべての企業に関する詳細な調査のリスト """
    research_list: List[TrendingCompanyResearch] = Field(description="すべてのトレンド企業に関する包括的な調査")


@CrewBase
class StockPicker():
    """StockPicker crew"""

    agents_config = 'config/agents.yaml'
    tasks_config = 'config/tasks.yaml'

    # ３つのエージェントと３つのタスクを定義

    # ３つのエージェント

    # トレンド企業発見エージェント
    @agent
    def trending_company_finder(self) -> Agent:
        return Agent(config=self.agents_config['trending_company_finder'],
                     tools=[SerperDevTool()], memory=True)

    # 財務リサーチエージェント
    @agent
    def financial_researcher(self) -> Agent:
        return Agent(config=self.agents_config['financial_researcher'], 
                     tools=[SerperDevTool()])
    
    # 株式銘柄選択エージェント
    @agent
    def stock_picker(self) -> Agent:
        return Agent(config=self.agents_config['stock_picker'], 
                     tools=[PushNotificationTool()], memory=True)
    
    # ３つのタスク

    # トレンド企業発見タスク
    @task
    def find_trending_companies(self) -> Task:
        return Task(
            config=self.tasks_config['find_trending_companies'],
            output_pydantic=TrendingCompanyList,
        )

    # 財務リサーチタスク
    @task
    def research_trending_companies(self) -> Task:
        return Task(
            config=self.tasks_config['research_trending_companies'],
            output_pydantic=TrendingCompanyResearchList,
        )

    # 株式銘柄選択タスク
    @task
    def pick_best_company(self) -> Task:
        return Task(
            config=self.tasks_config['pick_best_company'],
        )

    # クルーの定義
    @crew
    def crew(self) -> Crew:
        """StockPickerチームを結成"""

        # マネージャー・エージェントの定義
        manager = Agent(
            config=self.agents_config['manager'],
            allow_delegation=True
        )

        # クルーの定義
        return Crew(
            agents=self.agents,
            tasks=self.tasks, 
            process=Process.hierarchical, # ヒエラルキー実行モードの使用
            verbose=True,

            # マネージャー・エージェントの指定
            manager_agent=manager,
            #manager_llm=OpenAIChat(model="gpt-4o-mini"), # みたいな感じにもできるらしい。

            # メモリ設定
            memory=True,
            
            # 長期メモリ（SQLite）
            long_term_memory = LongTermMemory(
                storage=LTMSQLiteStorage(
                    db_path="./memory/long_term_memory_storage.db"
                )
            ),

            # 短期メモリ（RAG → VBD → ChromaDB）
            short_term_memory = ShortTermMemory(
                storage = RAGStorage(
                    embedder_config={
                        "provider": "openai",
                        "config": {
                            "model": 'text-embedding-3-small'
                        }
                    },
                    type="short_term",
                    path="./memory/"
                )
            ),
                
            # エンティティメモリ（RAG → VBD → ChromaDB）
            entity_memory = EntityMemory(
                storage=RAGStorage(
                    embedder_config={
                        "provider": "openai",
                        "config": {
                            "model": 'text-embedding-3-small'
                        }
                    },
                    type="short_term",
                    path="./memory/"
                )
            ),
        )
