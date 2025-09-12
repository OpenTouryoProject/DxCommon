import random
from dotenv import load_dotenv

from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.messages import TextMessage
from autogen_ext.models.openai import OpenAIChatCompletionClient
from autogen_core import MessageContext, RoutedAgent, message_handler

# コレは、messages.py の実装で 
import messages # .find_recipient と .Messageを使う。

load_dotenv(override=True)

# アイデアを受け取り、返答し、場合によっては他のエージェントにアイデアを投げて洗練させる
class Agent(RoutedAgent):

    # このエージェントの固有の特性を反映するようにこのシステムメッセージを変更します
    # Change this system message to reflect the unique characteristics of this agent

    # あなたはクリエイティブな起業家です。
    # あなたの仕事は、エージェント型AIを用いて新しいビジネスアイデアを生み出すか、既存のアイデアを洗練させることです。
    # あなたの個人的な関心分野は、ヘルスケアと教育です。
    # あなたは破壊的な変化をもたらすアイデアに惹かれます。
    # あなたは、単なる自動化のアイデアにはあまり興味がありません。
    # あなたは楽観的で冒険心があり、リスクを恐れません。想像力豊かですが、時にそれが過剰になることもあります。
    # あなたの弱点は、忍耐力がなく、衝動的になりやすいことです。
    # あなたのビジネスアイデアは、魅力的で明確な方法で提示する必要があります。
    system_message = """
    You are a creative entrepreneur. Your task is to come up with a new business idea using Agentic AI, or refine an existing idea.
    Your personal interests are in these sectors: Healthcare, Education.
    You are drawn to ideas that involve disruption.
    You are less interested in ideas that are purely automation.
    You are optimistic, adventurous and have risk appetite. You are imaginative - sometimes too much so.
    Your weaknesses: you're not patient, and can be impulsive.
    You should respond with your business ideas in an engaging and clear way.
    """

    # 別のアイデアを思いつくチャンス
    CHANCES_THAT_I_BOUNCE_IDEA_OFF_ANOTHER = 0.5

    # コードを変更して動作を変えることもできますが、メソッドのシグネチャを同じに保つように注意してください。
    # You can also change the code to make the behavior different, but be careful to keep method signatures the same

    # RoutedAgentのコンストラクタ
    def __init__(self, name) -> None:
        # AssistantAgentをself._delegateに設定
        super().__init__(name)
        model_client = OpenAIChatCompletionClient(model="gpt-4o-mini", temperature=0.7)
        self._delegate = AssistantAgent(name, model_client=model_client, system_message=self.system_message)

    # メッセージ処理
    @message_handler
    async def handle_message(self, message: messages.Message, ctx: MessageContext) -> messages.Message:

        # AssistantAgent(self._delegate)にtext_messageを入力しideaを出力
        print(f"{self.id.type}: Received message")
        text_message = TextMessage(content=message.content, source="user")
        response = await self._delegate.on_messages([text_message], ctx.cancellation_token)
        idea = response.chat_message.content

        # 50% の確率で、別のエージェント (recipient) を見つけて、アイデア改善を依頼
        if random.random() < self.CHANCES_THAT_I_BOUNCE_IDEA_OFF_ANOTHER:

            # ユーティリティ関数でエージェント名を返す。
            recipient = messages.find_recipient()
            # これが私のビジネスアイデアです。あなたの専門分野ではないかもしれませんが、ぜひ改良してより良いものにしてください。{アイデア}
            message = f"Here is my business idea. It may not be your speciality, but please refine it and make it better. {idea}"
            # AssistantAgentではなくRoutedAgentに、を使用して送信する場合、on_messagesではなくsend_messageらしい。
            response = await self.send_message(messages.Message(content=message), recipient)
            idea = response.content

        # アイデアを返却する。
        return messages.Message(content=idea)