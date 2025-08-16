import os
import json
from typing import Optional, List
from openai import OpenAI
from agents.deals import ScrapedDeal, DealSelection
from agents.agent import Agent

# ScrapedDeal や get_recommendationsをエージェント化
class ScannerAgent(Agent):

    # OpenAI の構造化出力（Structured Output） 機能を使う
    MODEL = "gpt-4o-mini"

    # 構造化出力用のシステム・プロンプト（get_recommendationsと同じ）
    SYSTEM_PROMPT = """
    You identify and summarize the 5 most detailed deals from a list, by selecting deals that have the most detailed, high quality description and the most clear price.
    Respond strictly in JSON with no explanation, using this format. You should provide the price as a number derived from the description. If the price of a deal isn't clear, do not include that deal in your response.
    Most important is that you respond with the 5 deals that have the most detailed product description with price. It's not important to mention the terms of the deal; most important is a thorough description of the product.
    Be careful with products that are described as "$XXX off" or "reduced by $XXX" - this isn't the actual price of the product. Only respond with products when you are highly confident about the price. 
    
    {"deals": [
        {
            "product_description": "Your clearly expressed summary of the product in 4-5 sentences. Details of the item are much more important than why it's a good deal. Avoid mentioning discounts and coupons; focus on the item itself. There should be a paragpraph of text for each item you choose.",
            "price": 99.99,
            "url": "the url as provided"
        },
        ...
    ]}
    """

    # 構造化出力用のユーザ・プロンプト_PREFIX（get_recommendationsと同じ）
    USER_PROMPT_PREFIX = """
    Respond with the most promising 5 deals from this list, selecting those which have the most detailed, high quality product description and a clear price that is greater than 0.
    Respond strictly in JSON, and only JSON. You should rephrase the description to be a summary of the product itself, not the terms of the deal.
    Remember to respond with a paragraph of text in the product_description field for each of the 5 items that you select.
    Be careful with products that are described as "$XXX off" or "reduced by $XXX" - this isn't the actual price of the product. Only respond with products when you are highly confident about the price. 
    
    Deals:
    """

    # 構造化出力用のユーザ・プロンプト_SUFFIX
    # 厳密に JSON で応答し、正確に 5 件の取引を含めます。それ以上は含めません。
    USER_PROMPT_SUFFIX = "\n\nStrictly respond in JSON and include exactly 5 deals, no more."

    name = "Scanner Agent"
    color = Agent.CYAN

    # 初期化（OpenAI）
    def __init__(self):
        """
        Set up this instance by initializing OpenAI
        OpenAIを初期化してこのインスタンスをセットアップする
        """
        # Scanner Agentの初期化中
        self.log("Scanner Agent is initializing")
        
        self.openai = OpenAI()

        # Scanner Agentの準備が完了
        self.log("Scanner Agent is ready")

    # RSSフィードの新しい取引のみを返す。
    def fetch_deals(self, memory) -> List[ScrapedDeal]:
        """
        Look up deals published on RSS feeds return any new deals that are not already in the memory provided
        RSSフィードで公開された取引を検索すると、提供されたメモリにまだ存在しない新しい取引が返されます。
        """
        # Scanner AgentはRSSフィードから取引を取得します
        self.log("Scanner Agent is about to fetch deals from RSS feed")

        # urlsをIDのように使用して重複を防止
        urls = [opp.deal.url for opp in memory] # 初登場のmemoryはAgentの機能！
        scraped = ScrapedDeal.fetch()
        result = [scrape for scrape in scraped if scrape.url not in urls]

        # Scanner Agentは、まだスクレイピングされていない取引を{len(result)}件受信
        self.log(f"Scanner Agent received {len(result)} deals not already scraped")
        
        return result

    # ユーザー・プロンプト作成
    def make_user_prompt(self, scraped) -> str:
        """
        Create a user prompt for OpenAI based on the scraped deals provided
        提供されたスクレイピングされた取引に基づいてOpenAIのユーザー・プロンプトを作成
        """
        user_prompt = self.USER_PROMPT_PREFIX
        user_prompt += '\n\n'.join([scrape.describe() for scrape in scraped])
        user_prompt += self.USER_PROMPT_SUFFIX
        return user_prompt

    # RSSフィードをスキャンし構造化出力
    def scan(self, memory: List[str]=[]) -> Optional[DealSelection]:
        """
        Call OpenAI to provide a high potential list of deals with good descriptions and prices
        Use StructuredOutputs to ensure it conforms to our specifications
        :param memory: a list of URLs representing deals already raised
        :return: a selection of good deals, or None if there aren't any

        OpenAI を呼び出して、適切な説明と価格が記載された、潜在力の高い取引リストを作成。
        StructuredOutputs を使用して、仕様に準拠していることを確認します。
        :param memory: 既に発生した取引を表す URL のリスト
        :return: 魅力的な取引の選択肢、または該当する取引がない場合は None を返します。
        """
        # RSSフィードの新しい取引が...
        scraped = self.fetch_deals(memory)

        # ...取得できた場合、
        if scraped:
            # プロンプトを作成し
            user_prompt = self.make_user_prompt(scraped)

            # Scanner AgentはOpenAIを呼び出し構造化出力を使用
            self.log("Scanner Agent is calling OpenAI using Structured Output")
            
            # OpenAI の構造化出力（Structured Output）機能
            result = self.openai.beta.chat.completions.parse(
                # OpenAIのモデル
                model=self.MODEL,
                # モデルへのプロンプト
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                # Python の特定の型（DealSelection）...
                response_format=DealSelection
            )

            # 実行結果をDealSelection型にパース
            result = result.choices[0].message.parsed
            
            # 価格が設定されていないものは破棄
            result.deals = [deal for deal in result.deals if deal.price>0]

            # Scanner Agentは、OpenAI から価格 >0 の選択された取引を {len(result.deals)} 件受信
            self.log(f"Scanner Agent received {len(result.deals)} selected deals with price>0 from OpenAI")
            
            return result # DealSelection = Dealのlist
        return None
                
