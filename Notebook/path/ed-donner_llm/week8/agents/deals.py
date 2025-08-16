from pydantic import BaseModel
from typing import List, Dict, Self
from bs4 import BeautifulSoup
import re
import feedparser
from tqdm import tqdm
import requests
import time

##################################################
# RSSのスクレイピング
##################################################

# 対象RSSフィードの定義
feeds = [
    # DealNews - Best Electronic Deals Online - Daily Electronics Deal
    # DealNews - オンラインで最高の電子機器のお買い得情報 - 毎日の電子機器のお買い得情報
    "https://www.dealnews.com/c142/Electronics/?rss=1",
    # DealNews - Best Computer Deals | Computers for Sale
    # DealNews - 最高のコンピューターのお買い得情報 | セール中のコンピューター
    "https://www.dealnews.com/c39/Computers/?rss=1",
    # DealNews - Discount Auto Parts & Best Automotive Deals
    # DealNews - 割引自動車部品と最高の自動車のお買い得情報
    "https://www.dealnews.com/c238/Automotive/?rss=1",
    # DealNews - Best Smart Home Device Deals
    # DealNews - スマートホームデバイスのお買い得情報
    "https://www.dealnews.com/f1912/Smart-Home/?rss=1",
    # DealNews - Home and Garden Deals - Housewares and Home Improvement Deals
    # DealNews - ホーム＆ガーデンのお買い得情報 - 家庭用品と住宅改修のお買い得情報
    "https://www.dealnews.com/c196/Home-Garden/?rss=1",
    ]

# HTMLスニペットからテキスト抽出
# RSSの<item>中の<div class="snippet summary"...＞</div>の中のテキストだけを抽出
def extract(html_snippet: str) -> str:
    """
    Use Beautiful Soup to clean up this HTML snippet and extract useful text
    Beautiful Soupを使用して、このHTMLスニペットをクリーンアップし、有用なテキストを抽出します。
    """

    # <item>中の主要コンテンツは<div class="snippet summary"...＞</div>の中
    soup = BeautifulSoup(html_snippet, 'html.parser')
    snippet_div = soup.find('div', class_='snippet summary')
    
    if snippet_div:
        # snippet( summary_div) -> description
        description = snippet_div.get_text(strip=True)
        # 更にパースしタグ除去＆デコード等を行う。
        description = BeautifulSoup(description, 'html.parser').get_text()
        # 正規表現でさらにタグ除去
        description = re.sub('<[^<]+?>', '', description)
        # 前後の空白や改行を削除
        result = description.strip()
        
    else: # ターゲットがなかった場合そのまま
        result = html_snippet

    # 改行をスペースに置換
    return result.replace('\n', ' ')

# 取引情報のスクレイピングクラス
# RSSフィードのエントリから詳細情報を取得して整形
class ScrapedDeal:
    """
    A class to represent a Deal retrieved from an RSS feed
    RSSフィードから取得した取引情報クラス
    """
    category: str
    title: str
    summary: str
    url: str
    details: str
    features: str

    # 初期化
    def __init__(self, entry: Dict[str, str]):
        """
        Populate this instance based on the provided dict
        提供された辞書に基づいてこのインスタンスを作成
        """

        # Itemのタイトル
        self.title = entry['title']
        
        # Itemのタイトル以外から主要コンテンツを抽出
        self.summary = extract(entry['summary'])

        # リンク情報の最初のリンクを保存
        self.url = entry['links'][0]['href']

        # 詳細ページをリクエスト
        stuff = requests.get(self.url).content
        
        # HTML解析（BeautifulSoup）
        soup = BeautifulSoup(stuff, 'html.parser')

        # 主要なテキストの抽出
        content = soup.find('div', class_='content-section').get_text()

        # 改行や余計な文字を整形
        content = content.replace('\nmore', '').replace('\n', ' ')

        # 「Features」という区切りがある場合は分割
        if "Features" in content:
            self.details, self.features = content.split("Features")
        else:
            self.details = content
            self.features = ""

    def __repr__(self):
        """
        Return a string to describe this deal
        この取引を説明する文字列を返す
        """
        return f"<{self.title}>"

    def describe(self):
        """
        Return a longer string to describe this deal for use in calling a model
        モデルの呼び出しに使用するために、この取引を説明する長い文字列を返す
        """
        return f"Title: {self.title}\nDetails: {self.details.strip()}\nFeatures: {self.features.strip()}\nURL: {self.url}"

    # 複数のRSSフィードからScrapedDeal（自クラスの）オブジェクトをまとめて生成
    @classmethod # インスタンス化せずに呼び出せる メソッド
    def fetch(cls, show_progress : bool = False) -> List[Self]:
        """
        Retrieve all deals from the selected RSS feeds
        選択したRSSフィードから最新x件だけ取引を取得
        """
        deals = []

        # 三項演算子で、feed_iter は tqdm(feeds) or feeds
        feed_iter = tqdm(feeds) if show_progress else feeds
        for feed_url in feed_iter:
            # 各フィードをパース
            feed = feedparser.parse(feed_url)
            # 最新5件のエントリで初期化
            for entry in feed.entries[:5]:
                # 自クラスを初期化・追加
                deals.append(cls(entry))
                time.sleep(0.5) # 負荷軽減
        
        # 自クラスのリストを返す
        return deals

##################################################
# データ構造定義（Pydanticモデル）
##################################################

# Deal: 商品の説明、価格、URL
class Deal(BaseModel):
    """
    A class to Represent a Deal with a summary description
    概要説明付きの取引を表すクラス
    """
    product_description: str
    price: float
    url: str

# データ構造定義（Pydanticモデル）
# DealSelection: 複数のDealを保持。
class DealSelection(BaseModel):
    """
    A class to Represent a list of Deals
    取引のリストを表すクラス
    """
    deals: List[Deal]

# データ構造定義（Pydanticモデル）
# Opportunity: 取引情報に対し、推定価格と割引額を付与した「お得度評価」。
class Opportunity(BaseModel):
    """
    A class to represent a possible opportunity: a Deal where we estimate it should cost more than it's being offered
    可能性のある機会を表すクラス: 提示されている金額よりも高い金額で取引が行われると見積もられる取引
    """
    deal: Deal
    estimate: float
    discount: float