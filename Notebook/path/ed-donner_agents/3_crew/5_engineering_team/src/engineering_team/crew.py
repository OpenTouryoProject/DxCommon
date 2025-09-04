from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task

@CrewBase
class EngineeringTeam():
    """EngineeringTeam crew"""

    agents_config = 'config/agents.yaml'
    tasks_config = 'config/tasks.yaml'

    # ４つのエージェントと４つのタスクを定義
    
    # ４つのエージェント

    # リード・エンジニア
    @agent
    def engineering_lead(self) -> Agent:
        return Agent(
            config=self.agents_config['engineering_lead'],
            verbose=True,
        )

    # バックエンド・エンジニア
    @agent
    def backend_engineer(self) -> Agent:
        return Agent(
            config=self.agents_config['backend_engineer'],
            verbose=True,

            # コードを実行できる
            allow_code_execution=True,   # Enable code execution
            code_execution_mode="safe",  # Uses Docker for safety
            max_execution_time=500,      # Max execution time in seconds
            max_retry_limit=3            # Number of retries for code execution
        )
    
    # フロントエンド・エンジニア
    @agent
    def frontend_engineer(self) -> Agent:
        return Agent(
            config=self.agents_config['frontend_engineer'],
            verbose=True,
        )
    
    # テスト・エンジニア
    @agent
    def test_engineer(self) -> Agent:
        return Agent(
            config=self.agents_config['test_engineer'],
            verbose=True,

            # コードを実行できる
            allow_code_execution=True,   # Enable code execution
            code_execution_mode="safe",  # Uses Docker for safety
            max_execution_time=500,      # Max execution time in seconds
            max_retry_limit=3            # Number of retries for code execution
        )

    # ４つのタスク

    # 設計タスク
    @task
    def design_task(self) -> Task:
        return Task(
            config=self.tasks_config['design_task']
        )

    # バックエンド・コードタスク
    @task
    def backend_code_task(self) -> Task:
        return Task(
            config=self.tasks_config['backend_code_task'],
        )

    # フロントエンド・コードタスク
    @task
    def frontend_code_task(self) -> Task:
        return Task(
            config=self.tasks_config['frontend_code_task'],
        )

    # テスト・コードタスク
    @task
    def test_code_task(self) -> Task:
        return Task(
            config=self.tasks_config['test_code_task'],
        )   

    @crew
    def crew(self) -> Crew:
        """Creates the research crew"""
        return Crew(
            agents=self.agents,
            tasks=self.tasks,
            process=Process.sequential,
            verbose=True,
        )