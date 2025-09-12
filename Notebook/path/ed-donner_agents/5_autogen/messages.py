import os
import glob
import random
from dataclasses import dataclass
from autogen_core import AgentId

# Message：任意のメッセージ
@dataclass
class Message:
    content: str

# find_recipient：ファイルからエージェント名を取得
def find_recipient() -> AgentId:
    try:
        # ファイルを検索
        agent_files = glob.glob("agent*.py")
        agent_names = [os.path.splitext(file)[0] for file in agent_files]

        # 以下は対象外
        agent_names.remove("agent")
        agent_names.remove("agent_commented")

        # エージェントをランダムに選出
        agent_name = random.choice(agent_names)
        print(f"Selecting agent for refinement: {agent_name}")
        return AgentId(agent_name, "default")
        
    except Exception as e:
        print(f"Exception finding recipient: {e}")
        return AgentId("agent1", "default")
