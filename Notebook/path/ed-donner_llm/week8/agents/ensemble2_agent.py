import pandas as pd
from sklearn.linear_model import LinearRegression
import joblib

from agents.agent import Agent
from agents.specialist_agent import SpecialistAgent
from agents.frontier_agent import FrontierAgent
#from agents.random_forest_agent import RandomForestAgent
from agents.lightgbm_agent import LightGBMAgent

# アンサンブル・モデルのエージェント
class Ensemble2Agent(Agent):

    name = "Ensemble2 Agent"
    color = Agent.YELLOW

    # 初期化
    def __init__(self, collection):
        """
        Create an instance of Ensemble, by creating each of the models And loading the weights of the Ensemble
        各モデルを作成し、アンサンブルの重みをロードして、アンサンブルのインスタンスを作成
        """

        # アンサンブル・エージェントを初期化
        self.log("Initializing Ensemble Agent")

        # 各エージェントの初期化
        self.specialist = SpecialistAgent()
        self.frontier = FrontierAgent(collection)
        #self.random_forest = RandomForestAgent()
        self.lightgbm_agent = LightGBMAgent()
        
        # アンサンブル・モデルの初期化
        self.model = joblib.load('ensemble_model.pkl')

        # アンサンブル・エージェントの準備が完了
        self.log("Ensemble Agent is ready")

    # 価格の推定
    def price(self, description: str) -> float:
        """
        Run this ensemble model
        Ask each of the models to price the product
        Then use the Linear Regression model to return the weighted price
        :param description: the description of a product
        :return: an estimate of its price

        このアンサンブル・モデルを実行します
        各モデルに製品の価格設定を依頼します
        次に、線形回帰モデルを使用して加重価格を返します
        :param description: 製品の説明
        :return: 価格の推定値
        """

        # アンサンブル・エージェントの実行 - ３つのエージェントとの連携
        self.log("Running Ensemble Agent - collaborating with specialist, frontier and LightGBM agents")

        # 各エージェントで推論
        specialist = self.specialist.price(description)
        frontier = self.frontier.price(description)
        #random_forest = self.random_forest.price(description)
        lightgbm = self.lightgbm_agent.price(description)

        # 各モデルの予測誤差の傾向を線形回帰が重み付けして最適に組み合わせる
        X = pd.DataFrame({
            'Specialist': [specialist],
            'Frontier': [frontier],
            #'RandomForest': [random_forest],
            'LightGBM': [lightgbm],
            'Min': [min(specialist, frontier, lightgbm)], #random_forest)],
            'Max': [max(specialist, frontier, lightgbm)], #random_forest)],
        })
        y = max(0, self.model.predict(X)[0])

        # アンサンブル・エージェントが完了 - ${result:.2f}を予測
        self.log(f"Ensemble Agent complete - returning ${y:.2f}")
        
        return y