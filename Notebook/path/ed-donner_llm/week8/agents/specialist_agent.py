import modal
from agents.agent import Agent

# ファインチューニングされたLLMのエージェント
class SpecialistAgent(Agent):
    """
    An Agent that runs our fine-tuned LLM that's running remotely on Modal
    Modal上でリモートで実行される、ファインチューニングされたLLMを実行するエージェント
    """

    name = "Specialist Agent"
    color = Agent.RED

    # 初期化
    def __init__(self):
        """
        Set up this Agent by creating an instance of the modal class
        Modalクラスのインスタンスを作成してこのエージェントを設定
        """

        # ファインチューニングされたLLMのエージェントの初期化中 - モーダルに接続中
        self.log("Specialist Agent is initializing - connecting to modal")

        # 事前に、Modalクラスが、pricer-serviceと言う名称で登録されていること
        Pricer = modal.Cls.from_name("pricer-service", "Pricer")
        self.pricer = Pricer()

        # ファインチューニングされたLLMのエージェントの準備が完了
        self.log("Specialist Agent is ready")

    # itemのプロンプトからファインチューニングされたLLMで推定した値を返す
    def price(self, description: str) -> float:
        """
        Make a remote call to return the estimate of the price of this item
        この商品の価格の見積もりを返すためにリモート呼び出しを実行
        """
        
        # ファインチューニングされたLLMのエージェントがリモート呼び出し
        self.log("Specialist Agent is calling remote fine-tuned model")
        
        result = self.pricer.price.remote(description)

        # ファインチューニングされたLLMのエージェントが完了 - ${result:.2f} を予測
        self.log(f"Specialist Agent completed - predicting ${result:.2f}")
        
        return result