# imports

import os
import re
import math
import json
from typing import List, Dict

from openai import OpenAI
from datasets import load_dataset

import chromadb
from sentence_transformers import SentenceTransformer

from items import Item
from testing import Tester
from agents.agent import Agent

# Frontier LLM ＋ RAG のエージェント
class FrontierAgent(Agent):

    name = "Frontier Agent"
    color = Agent.BLUE

    MODEL = "gpt-4o-mini"

    # 初期化
    def __init__(self, collection):
        """
        Set up this instance by connecting to OpenAI or DeepSeek, to the Chroma Datastore, And setting up the vector encoding model
        このインスタンスを OpenAI または DeepSeek に接続して Chroma Datastore に接続し、埋め込みモデルを設定（≒ day2.3_ja.ipynbの内容）
        """
        
        self.log("Initializing Frontier Agent")
        deepseek_api_key = os.getenv("DEEPSEEK_API_KEY")
        
        if deepseek_api_key: # deepseek-chat
            self.client = OpenAI(api_key=deepseek_api_key, base_url="https://api.deepseek.com")
            self.MODEL = "deepseek-chat"
            self.log("Frontier Agent is set up with DeepSeek")
        
        else:                # gpt-4o-mini
            self.client = OpenAI()
            self.MODEL = "gpt-4o-mini"
            self.log("Frontier Agent is setting up with OpenAI")
        
        self.collection = collection
        self.model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
        self.log("Frontier Agent is ready")

    # RAGで取得した製品情報チャンクからコンテキストを生成
    def make_context(self, similars: List[str], prices: List[float]) -> str:
        """
        Create context that can be inserted into the prompt
        :param similars: similar products to the one being estimated
        :param prices: prices of the similar products
        :return: text to insert in the prompt that provides context

        プロンプトに挿入できるコンテキストを作成します
        :param similars: 見積り対象の商品に類似する商品
        :param prices: 類似商品の価格
        :return: プロンプトに挿入するコンテキストを示すテキスト
        """

        # 背景を説明すると、見積もる必要のある項目に類似している可能性のある他の項目をいくつか示します。
        message = "To provide some context, here are some other items that might be similar to the item you need to estimate.\n\n"
        
        for similar, price in zip(similars, prices):
            # message += of"潜在的に関連のある製品:\in{similar}\価格は ${price:.2f}\n\n"
            message += f"Potentially related product:\n{similar}\nPrice is ${price:.2f}\n\n"
        return message

    # 製品情報とチャンクからプロンプトを生成
    def messages_for(self, description: str, similars: List[str], prices: List[float]) -> List[Dict[str, str]]:
        """
        Create the message list to be included in a call to OpenAI with the system and user prompt
        :param description: a description of the product
        :param similars: similar products to this one
        :param prices: prices of similar products
        :return: the list of messages in the format expected by OpenAI

        システムとユーザープロンプトを使用して、OpenAIへの呼び出しに含めるメッセージリストを作成。
        :param description: 商品の説明
        :param similars: 類似商品
        :param prices: 類似商品の価格
        :return: OpenAIが期待する形式のメッセージリスト
        """

        # 商品の価格を見積もる。価格のみを返信し、説明は不要。
        system_message = "You estimate prices of items. Reply only with the price, no explanation"

        # RAGで取得した製品情報チャンクからコンテキストを生成
        user_prompt = self.make_context(similars, prices) # 前述の関数を呼び出す

        # さて、あなたへの質問です
        user_prompt += "And now the question for you:\n\n"

        # これはいくらですか？
        user_prompt += "How much does this cost?\n\n" + description

        # プロンプト
        return [
            {"role": "system", "content": system_message},
            {"role": "user", "content": user_prompt},
            {"role": "assistant", "content": "Price is $"}
        ]

    # 製品情報チャンク（ベクトルと類似の元文書と価格）を取得
    def find_similars(self, description: str):
        """
        Return a list of items similar to the given one by looking in the Chroma datastore
        Chromaデータストアを参照して、指定されたアイテムに類似したアイテムのリストを返します。
        """

        # Frontier Agent は ChromaデータストアのRAG検索を実行して、5つの類似製品を検索
        self.log("Frontier Agent is performing a RAG search of the Chroma datastore to find 5 similar products")
        
        vector = self.model.encode([description])
        results = self.collection.query(query_embeddings=vector.astype(float).tolist(), n_results=5)
        documents = results['documents'][0][:]
        prices = [m['price'] for m in results['metadatas'][0][:]]

        # フロンティアエージェントは類似の製品を見つけました
        self.log("Frontier Agent has found similar products")
        
        return documents, prices

    # 文字列から価格を抽出する関数
    def get_price(self, s) -> float:
        """
        A utility that plucks a floating point number out of a string
        文字列から浮動小数点数を取り出すユーティリティ
        """
        s = s.replace('$','').replace(',','')
        match = re.search(r"[-+]?\d*\.\d+|\d+", s)
        return float(match.group()) if match else 0.0

    # itemのプロンプトからFrontier LLM＋RAGで推定した値を返す
    def price(self, description: str) -> float:
        """
        Make a call to OpenAI or DeepSeek to estimate the price of the described product,
        by looking up 5 similar products and including them in the prompt to give context
        :param description: a description of the product
        :return: an estimate of the price

        OpenAI または DeepSeek を呼び出して、説明されている製品の価格を推定します。
        類似製品を 5 つ検索し、それらをプロンプトに含めることでコンテキストを提供します。
        :param description: 製品の説明
        :return: 価格の推定値
        """
        documents, prices = self.find_similars(description) # 前述の関数を呼び出す

        # Frontier Agent は、5 つの類似製品を含むコンテキストで {self.MODEL} を呼び出す。
        self.log(f"Frontier Agent is about to call {self.MODEL} with context including 5 similar products")
        
        response = self.client.chat.completions.create(
            model=self.MODEL, 
            messages=self.messages_for(description, documents, prices), # 前述の関数を呼び出す
            seed=42,
            max_tokens=5
        )
        
        reply = response.choices[0].message.content
        result = self.get_price(reply) # 前述の関数を呼び出す

        # フロンティア・エージェントが完了しました - ${result:.2f}と予測
        self.log(f"Frontier Agent completed - predicting ${result:.2f}")
        
        return result