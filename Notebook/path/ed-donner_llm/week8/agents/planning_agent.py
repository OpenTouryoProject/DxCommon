from typing import Optional, List
from agents.agent import Agent
from agents.deals import ScrapedDeal, DealSelection, Deal, Opportunity
from agents.scanner_agent import ScannerAgent
#from agents.ensemble_agent import EnsembleAgent
from agents.ensemble2_agent import Ensemble2Agent
from agents.messaging_agent import MessagingAgent

# 計画エージェント
# これは、取引検出〜見積〜通知までを自動化
class PlanningAgent(Agent):

    name = "Planning Agent"
    color = Agent.GREEN
    DEAL_THRESHOLD = 50

    # 初期化
    def __init__(self, collection):
        """
        Create instances of the 3 Agents that this planner coordinates across
        このプランナーが調整する3人のエージェントのインスタンスを作成
        """

        # Planning Agentの初期化中
        self.log("Planning Agent is initializing")

        # 3種類のエージェントをインスタンス化して準備
        self.scanner = ScannerAgent()
        self.ensemble = Ensemble2Agent(collection) #EnsembleAgent(collection)
        self.messenger = MessagingAgent()

        # Planning Agentの準備が完了
        self.log("Planning Agent is ready")

    # 取引を商談に変換
    def run(self, deal: Deal) -> Opportunity:
        """
        Run the workflow for a particular deal
        :param deal: the deal, summarized from an RSS scrape
        :returns: an opportunity including the discount

        特定の取引のワークフローを実行
        :param deal: RSSスクレイピングから要約された取引
        :returns: 割引を含む商談
        """

        # Planning Agentは取引の価格を設定
        self.log("Planning Agent is pricing up a potential deal")

        # 商品の説明から価格推定
        estimate = self.ensemble.price(deal.product_description)
        # 実際の価格との差を算出
        discount = estimate - deal.price

        # Planning Agentは${discount:.2f}割引で取引を処理
        self.log(f"Planning Agent has processed a deal with discount ${discount:.2f}")

        # 結果を商談まとめる。
        return Opportunity(deal=deal, estimate=estimate, discount=discount)

    # 全体のワークフロー
    def plan(self, memory: List[str] = []) -> Optional[Opportunity]:
        """
        Run the full workflow:
        1. Use the ScannerAgent to find deals from RSS feeds
        2. Use the EnsembleAgent to estimate them
        3. Use the MessagingAgent to send a notification of deals
        :param memory: a list of URLs that have been surfaced in the past
        :return: an Opportunity if one was surfaced, otherwise None

        ワークフロー全体を実行
        1. ScannerAgent を使用して RSS フィードから取引を検索
        2. EnsembleAgent を使用して取引を見積もり
        3. MessagingAgent を使用して取引の通知を送信
        :param memory: 過去に掲載された URL のリスト
        :return: 掲載された場合は Opportunity、そうでない場合は None を返しす。
        """

        # Planning Agentが実行を開始
        self.log("Planning Agent is kicking off a run")

        # ScannerAgent で RSS フィードから新しい取引情報を取得
        selection = self.scanner.scan(memory=memory)

        # 見つかった取引の...
        if selection:
            
            # ...最大5件を取引を商談に変換
            opportunities = [self.run(deal) for deal in selection.deals[:5]]
            # 割引額の大きい順にソート
            opportunities.sort(key=lambda opp: opp.discount, reverse=True)
            # 最良の1件を選択
            best = opportunities[0]

            # Planning Agentは、割引額が ${best.discount:.2f} である最良の取引を特定
            self.log(f"Planning Agent has identified the best deal has discount ${best.discount:.2f}")

            # 割引額が 閾値以上なら通知
            if best.discount > self.DEAL_THRESHOLD:
                self.messenger.alert(best)

            # Planning Agentが実行を完了
            self.log("Planning Agent has completed a run")

            # 割引が閾値以上なら Opportunity それ以外は None。
            return best if best.discount > self.DEAL_THRESHOLD else None
        return None