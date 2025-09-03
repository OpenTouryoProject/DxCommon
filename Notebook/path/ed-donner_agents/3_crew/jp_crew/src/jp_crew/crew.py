from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task
from crewai.agents.agent_builder.base_agent import BaseAgent
from typing import List

# CrewAIは、複数の AI エージェントが、タスクを協力して進める仕組みを提供するフレームワーク。
# この JpCrew クラスは、@agent, @task, @crew デコレータでエージェント・タスク・クルーを定義している。
# - どんなエージェントを使うか（researcher, reporting_analyst）
# - どんなタスクを実行するか（research_task, reporting_task）
# - それらをどんなプロセスで実行するか（ここでは sequential＝順番に実行）

# クルーがスタートする前または後にコードスニペットを実行したい場合は、
# @before_kickoff および @after_kickoff デコレータを使用できます
# https://docs.crewai.com/concepts/crews#example-crew-class-with-decorators

@CrewBase
class JpCrew():
    """JpCrew crew"""

    agents: List[BaseAgent]
    tasks: List[Task]

    # YAML 構成ファイルの詳細については、こちらをご覧ください。
    # Agents: https://docs.crewai.com/concepts/agents#yaml-configuration-recommended
    # Tasks: https://docs.crewai.com/concepts/tasks#yaml-configuration-recommended
    
    # エージェントにツールを追加したい場合は、こちらで詳細をご覧ください。:
    # https://docs.crewai.com/concepts/agents#agent-tools

    # ＜エージェントの定義＞
    # researcher というエージェントを生成。
    @agent
    def researcher(self) -> Agent:
        return Agent(
            # YAML/JSON 設定を読み込んで動作を決める。
            config=self.agents_config['researcher'], # type: ignore[index]
            # 詳細なログを出す。
            verbose=True
        )
    
    # reporting_analyst というエージェントを生成。
    @agent
    def reporting_analyst(self) -> Agent:
        return Agent(
            # YAML/JSON 設定を読み込んで動作を決める。
            config=self.agents_config['reporting_analyst'], # type: ignore[index]
            # 詳細なログを出す。
            verbose=True
        )

    # 構造化されたタスク出力、タスクの依存関係、タスクのコールバックの詳細については、次のドキュメントをご覧ください。
    # https://docs.crewai.com/concepts/tasks#overview-of-a-task

    # ＜タスクの定義＞
    # research_task というタスクを生成。
    @task
    def research_task(self) -> Task:
        return Task(
            # YAML/JSON 設定を読み込んで動作を決める。
            config=self.tasks_config['research_task'], # type: ignore[index]
        )

    # reporting_task というタスクを生成。
    @task
    def reporting_task(self) -> Task:
        return Task(
            # YAML/JSON 設定を読み込んで動作を決める。
            config=self.tasks_config['reporting_task'], # type: ignore[index]
            # 出力を report.md に保存する。
            output_file='report.md'
        )

    # ＜クルーを定義する＞
    @crew
    def crew(self) -> Crew:
        """JpCrewクルーを作成する"""
        # クルーに知識ソースを追加する方法については、ドキュメントをご覧ください。:
        # https://docs.crewai.com/concepts/knowledge#what-is-knowledge

        return Crew(
            agents=self.agents, # @agent デコレータによって自動的に作成される
            tasks=self.tasks, # @task デコレータによって自動的に作成される
            process=Process.sequential, # research_task → reporting_task の順でタスク実行
            verbose=True, # 実行ログを詳細に出す。
            # process=Process.hierarchical, # 代わりにこれを使用したい場合は https://docs.crewai.com/how-to/Hierarchical/ を参照してください
        )
