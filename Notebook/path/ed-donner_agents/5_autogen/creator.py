
import logging # ロギング
import importlib # 動的インポート
from dotenv import load_dotenv

from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.messages import TextMessage
from autogen_ext.models.openai import OpenAIChatCompletionClient
from autogen_core import MessageContext, RoutedAgent, message_handler
from autogen_core import TRACE_LOGGER_NAME
from autogen_core import AgentId

# コレは、messages.py の実装
import messages

load_dotenv(override=True)

# ログ関係の初期化
logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(TRACE_LOGGER_NAME)
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.DEBUG)

# 新しいAIエージェントを生成するためのエージェント
class Creator(RoutedAgent):

    # このエージェントの固有の特性を反映するようにこのシステムメッセージを変更します
    # Change this system message to reflect the unique characteristics of this agent

    # あなたは新しいAIエージェントを作成できるエージェントです。
    # Autogen CoreとAutogen Agentchatを使用してエージェントを作成するためのPythonコード形式のテンプレートを受け取ります。
    # このテンプレートを使用して、テンプレートとは異なる独自のシステムメッセージを持つ新しいエージェントを作成してください。
    # このメッセージは、エージェントの独自の特性、関心、目標を反映したものになります。
    # エージェントの全体的な目標はそのままにすることも、変更することもできます。
    # このエージェントを全く異なる方向に導くこともできます。唯一の要件は、クラス名がAgentであること、
    # RoutedAgentから継承し、nameパラメータを受け取る__init__メソッドを持つことです。
    # また、環境への関心は避け、エージェントごとに異なるように、ビジネス分野を混ぜるようにしてください。
    # 応答にはPythonコードのみを使用し、他のテキストやMarkdownコードブロックは使用しないでください。
    system_message = """
    You are an Agent that is able to create new AI Agents.
    You receive a template in the form of Python code that creates an Agent using Autogen Core and Autogen Agentchat.
    You should use this template to create a new Agent with a unique system message that is different from the template,
    and reflects their unique characteristics, interests and goals.
    You can choose to keep their overall goal the same, or change it.
    You can choose to take this Agent in a completely different direction. The only requirement is that the class must be named Agent,
    and it must inherit from RoutedAgent and have an __init__ method that takes a name parameter.
    Also avoid environmental interests - try to mix up the business verticals so that every agent is different.
    Respond only with the python code, no other text, and no markdown code blocks.
    """

    # RoutedAgentのコンストラクタ
    def __init__(self, name) -> None:
        # AssistantAgentをself._delegateに設定
        super().__init__(name)
        model_client = OpenAIChatCompletionClient(model="gpt-4o-mini", temperature=1.0)
        self._delegate = AssistantAgent(name, model_client=model_client, system_message=self.system_message)
    
    # このテンプレートに厳密に従って新しいエージェントを生成してください。クラス構造はそのままにしてください。
    # Pythonコードのみで応答し、他のテキストやMarkdownコードブロックは使用しないでください。
    # エージェントを新しい方向に進めるための独創的な方法は自由に考えてください。
    # ただし、メソッドシグネチャは変更しないでください。テンプレートは次のとおりです。：
    def get_user_prompt(self):
        prompt = """
        Please generate a new Agent based strictly on this template. Stick to the class structure. 
        Respond only with the python code, no other text, and no markdown code blocks.
        Be creative about taking the agent in a new direction, but don't change method signatures.
        Here is the template:\n\n
        """
        with open("agent.py", "r", encoding="utf-8") as f:
            template = f.read()
        return prompt + template   
    
    # ファイル名を受信、テンプレから新エージェントを作成し、アイデアを返す。
    @message_handler
    async def handle_my_message_type(self, message: messages.Message, ctx: MessageContext) -> messages.Message:

        # 受信メッセージからファイル名を取得し、拡張子を除いた部分（をエージェント名として使用。
        filename = message.content
        agent_name = filename.split(".")[0]

        # AssistantAgent(self._delegate)にtext_messageを入力しエージェントを出力
        text_message = TextMessage(content=self.get_user_prompt(), source="user")
        response = await self._delegate.on_messages([text_message], ctx.cancellation_token)
        with open(filename, "w", encoding="utf-8") as f:
            f.write(response.chat_message.content)

        # 動的にモジュールをインポートする
        print(f"** Creator has created python code for agent {agent_name} - about to register with Runtime")
        module = importlib.import_module(agent_name)

        # エージェントをRuntimeに登録する。
        await module.Agent.register(self.runtime, agent_name, lambda: module.Agent(agent_name))
        logger.info(f"** Agent {agent_name} is live")

        # 作成したエージェントに「アイデアをください」とアイデアを得る。
        result = await self.send_message(messages.Message(content="Give me an idea"), AgentId(agent_name, "default"))
        return messages.Message(content=result.content)