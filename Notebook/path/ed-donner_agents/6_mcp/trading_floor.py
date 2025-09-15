# 自動トレード用のスケジューラ

# 基本
import os
import asyncio
from typing import List

# OpneAI
from agents import add_trace_processor

# 自作
from market import is_market_open
from traders import Trader
from tracers import LogTracer

# 初期化
from dotenv import load_dotenv
load_dotenv(override=True)

# 環境変数
## 何分ごとに実行するか？デフォルトは 60 分
RUN_EVERY_N_MINUTES = int(os.getenv("RUN_EVERY_N_MINUTES", "60"))
## 市場が閉じていても処理を実行するかどうか？デフォルトは false。
RUN_EVEN_WHEN_MARKET_IS_CLOSED = (os.getenv("RUN_EVEN_WHEN_MARKET_IS_CLOSED", "false").strip().lower() == "true")
## 複数のモデルを使うかどうか？デフォルトは false。
USE_MANY_MODELS = (os.getenv("USE_MANY_MODELS", "false").strip().lower() == "true")

# トレーダーの名前と
names = ["Warren", "George", "Ray", "Cathie"]
# 投資スタイルを示すニックネーム
lastnames = ["Patience", "Bold", "Systematic", "Crypto"]

# 複数の AI モデルを使うか、同じモデルを使うかを切り替え。
if USE_MANY_MODELS:
    model_names = [
        "gpt-4.1-mini",
        "deepseek-chat",
        "gemini-2.5-flash-preview-04-17",
        "grok-3-mini-beta",
    ]
    short_model_names = ["GPT 4.1 Mini", "DeepSeek V3", "Gemini 2.5 Flash", "Grok 3 Mini"]
else:
    model_names = ["gpt-4o-mini"] * 4
    short_model_names = ["GPT 4o mini"] * 4

# 4トレーダー生成関数
def create_traders() -> List[Trader]:
    traders = []
    for name, lastname, model_name in zip(names, lastnames, model_names):
        traders.append(Trader(name, lastname, model_name))
    return traders

# スケジューラ処理
async def run_every_n_minutes():
    add_trace_processor(LogTracer()) # ログ記録の設定
    traders = create_traders()       # 4トレーダー生成
    
    while True: # トレーダーを定期実行
        if RUN_EVEN_WHEN_MARKET_IS_CLOSED or is_market_open():
            await asyncio.gather(*[trader.run() for trader in traders])
        else:
            print("Market is closed, skipping run")
        await asyncio.sleep(RUN_EVERY_N_MINUTES * 60)

# エントリポイントで非同期ループを開始
if __name__ == "__main__":
    print(f"Starting scheduler to run every {RUN_EVERY_N_MINUTES} minutes")
    asyncio.run(run_every_n_minutes())
