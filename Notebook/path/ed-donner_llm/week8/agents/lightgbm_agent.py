# imports

import os
import re
from typing import List
from sentence_transformers import SentenceTransformer
import joblib
from agents.agent import Agent

# LightGBMモデルのエージェント
class LightGBMAgent(Agent):

    name = "LightGBM Agent"
    color = Agent.MAGENTA

    # 初期化
    def __init__(self):
        """
        Initialize this object by loading in the saved model weights and the SentenceTransformer vector encoding model
        保存したモデルの重みとSentenceTransformerベクトルエンコーディングモデルを読み込んでこのオブジェクトを初期化
        """
        
        # LightGBMエージェントを初期化
        self.log("LightGBM Agent is initializing")
        
        self.vectorizer = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
        self.model = joblib.load('lightgbm_model.pkl')
        
        # LightGBMエージェントの準備が完了
        self.log("LightGBM Agent is ready")

    # 価格の推定
    def price(self, description: str) -> float:
        """
        Use a LightGBM model to estimate the price of the described item
        :param description: the product to be estimated
        :return: the price as a float

        LightGBMモデルを使用して、説明されている商品の価格を推定
        :param description: 推定する商品
        :return: float で表した価格
        """

        # LightGBMエージェントが予測を開始
        self.log("LightGBM Agent is starting a prediction")
        
        vector = self.vectorizer.encode([description])
        result = max(0, self.model.predict(vector)[0])
        
        # LightGBMエージェントが完了 - ${result:.2f}を予測
        self.log(f"RLightGBM Agent completed - predicting ${result:.2f}")
        
        return result