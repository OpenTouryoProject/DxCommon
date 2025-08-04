"""
このPythonコードは、製品情報からトレーニング用データ（プロンプトと正解値）を生成するための「Item」クラスを定義している。
・製品データ（タイトル、説明、特徴、詳細等）と価格を受け取り、不要テキストを削除・サニタイズして、適切なトークン数・長さに調整
・質問（How much does this cost...?）+ サニタイズされた商品説明 + 正しい価格を合成したプロンプトを生成
・トークン数・内容の基準を満たさない場合、対象外（include=False）にする。
"""

from typing import Optional
from transformers import AutoTokenizer
import re

# 使用するトークナイザー
BASE_MODEL = "meta-llama/Meta-Llama-3.1-8B"

# これより少ないと、有用なコンテンツが足りません
MIN_TOKENS = 150 # Any less than this, and we don't have enough useful content

# このトークン数を超えると切り捨てられます。プロンプトテキストを追加すると、約180トークンになります
MAX_TOKENS = 160 # Truncate after this many tokens. Then after adding in prompt text, we will get to around 180 tokens

MIN_CHARS = 300
CEILING_CHARS = MAX_TOKENS * 7

class Item:
    """
    An Item is a cleaned, curated datapoint of a Product with a Price
    アイテムとは、価格が設定された製品の、整理され、キュレーションされたデータポイントです。
    """
    
    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL, trust_remote_code=True)
    PREFIX = "Price is $"
    # 質問文（プロンプトの冒頭）...製品プライサー向けなのでこうなっている。
    QUESTION = "How much does this cost to the nearest dollar?" # これの費用は、最も近いドル単位でいくらですか？
    # 詳細データの中で削除すべきキーワードリスト
    REMOVALS = ['"Batteries Included?": "No"', '"Batteries Included?": "Yes"', '"Batteries Required?": "No"', '"Batteries Required?": "Yes"', "By Manufacturer", "Item", "Date First", "Package", ":", "Number of", "Best Sellers", "Number", "Product "]

    title: str
    price: float
    category: str
    token_count: int = 0
    details: Optional[str]
    prompt: Optional[str] = None
    include = False

    # data（dict: title, description, features, details等）と price　を受け取り初期化、parse()実行し、条件を満たす場合にプロンプト生成
    def __init__(self, data, price):
        self.title = data['title']
        self.price = price
        self.parse(data)

    # parse() から実行され、製品詳細テキストのクリーンナップ、self.detailsからREMOVALSに含まれる不要キーワードを削除
    def scrub_details(self):
        """
        Clean up the details string by removing common text that doesn't add value
        価値を追加しない一般的なテキストを削除して詳細文字列を整理します
        """
        details = self.details
        for remove in self.REMOVALS:
            details = details.replace(remove, "")
        return details

    # parse() から実行され、文字列から記号や余計な空白を削除（正規表現利用）「7文字以上かつ数字を含む単語」は削除 → 製品番号などノイズを排除
    def scrub(self, stuff):
        """
        Clean up the provided text by removing unnecessary characters and whitespace
        Also remove words that are 7+ chars and contain numbers, as these are likely irrelevant product numbers
        不要な文字と空白を削除して、提供されたテキストを整理してください。
        また、7文字以上で数字を含む単語も削除してください。これらはおそらく無関係な製品番号です。
        """
        stuff = re.sub(r'[:\[\]"{}【】\s]+', ' ', stuff).strip()
        stuff = stuff.replace(" ,", ",").replace(",,,",",").replace(",,",",")
        words = stuff.split(' ')
        select = [word for word in words if len(word)<7 or not any(char.isdigit() for char in word)]
        return " ".join(select)

    # __init__() から実行される parse()は、入力データを連結してmainテキスト生成、
    # 文字数制限/トークン長制限を超える場合は切り出し上記「scrub」「scrub_details」でテキストクリーニング
    # トークナイズして、MIN_TOKENS - MAX_TOKENS以内の場合、include = Trueとして、プロンプト生成。
    def parse(self, data):
        """
        Parse this datapoint and if it fits within the allowed Token range, then set include to True
        このデータポイントを解析し、許可されたトークン範囲内に収まる場合は、include を True に設定します。
        """
        contents = '\n'.join(data['description'])
        if contents:
            contents += '\n'
        features = '\n'.join(data['features'])
        if features:
            contents += features + '\n'
        self.details = data['details']
        if self.details:
            contents += self.scrub_details() + '\n'
        if len(contents) > MIN_CHARS:
            contents = contents[:CEILING_CHARS]
            text = f"{self.scrub(self.title)}\n{self.scrub(contents)}"
            tokens = self.tokenizer.encode(text, add_special_tokens=False)
            if len(tokens) > MIN_TOKENS:
                tokens = tokens[:MAX_TOKENS]
                text = self.tokenizer.decode(tokens)
                self.make_prompt(text)
                self.include = True

    # How much does this cost...? + 内容テキスト + Price is $<値>というフォーマットでプロンプトを作成
    #価格はドル単位に四捨五入、プロンプト全体のトークン数を計測
    def make_prompt(self, text):
        """
        Set the prompt instance variable to be a prompt appropriate for training
        プロンプト・インスタンス変数をトレーニングに適したプロンプトに設定する
        """
        self.prompt = f"{self.QUESTION}\n\n{text}\n\n"
        self.prompt += f"{self.PREFIX}{str(round(self.price))}.00"
        self.token_count = len(self.tokenizer.encode(self.prompt, add_special_tokens=False))
        
    # 答え（価格）部分を削除したプロンプトを返す（検証/推論用）
    def test_prompt(self):
        """
        Return a prompt suitable for testing, with the actual price removed
        実際の価格を削除した、テストに適したプロンプトを返す
        """
        return self.prompt.split(self.PREFIX)[0] + self.PREFIX
        
    # 表示用：<タイトル = $価格>の文字列
    def __repr__(self):
        """
        Return a String version of this Item
        このアイテムの文字列バージョンを返す
        """
        return f"<{self.title} = ${self.price}>"    

    
    