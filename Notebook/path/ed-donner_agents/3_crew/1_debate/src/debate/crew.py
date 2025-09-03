from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task

# 討論クルーの定義
@CrewBase
class Debate():
    """Debate crew"""

    agents_config = 'config/agents.yaml'
    tasks_config = 'config/tasks.yaml'
    
    # 2エージェントと3タスクを定義

    # 2つのエージェント

    # 討論者
    @agent
    def debater(self) -> Agent:
        return Agent(
            config=self.agents_config['debater'],
            verbose=True
        )
    
    # 審査者
    @agent
    def judge(self) -> Agent:
        return Agent(
            config=self.agents_config['judge'],
            verbose=True
        )
    
    # 3つのタスク
    
    # 提案する
    @task
    def propose(self) -> Task:
        return Task(
            config=self.tasks_config['propose'],
        )

    # 反対する
    @task
    def oppose(self) -> Task:
        return Task(
            config=self.tasks_config['oppose'],
        )

    # 決定する
    @task
    def decide(self) -> Task:
        return Task(
            config=self.tasks_config['decide'],
        )

    # クルーの定義
    @crew
    def crew(self) -> Crew:
        """Creates the Debate crew"""

        return Crew(
            agents=self.agents, # Automatically created by the @agent decorator
            tasks=self.tasks, # Automatically created by the @task decorator
            process=Process.sequential, # 同様にシーケンシャルに実行
            verbose=True,
        )
