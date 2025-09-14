import os
import random
from datetime import datetime
from datetime import timezone
from dotenv import load_dotenv

from polygon import RESTClient
from functools import lru_cache

from database import write_market, read_market

# 初期化
load_dotenv(override=True)

# Polygon.io
polygon_api_key = os.getenv("POLYGON_API_KEY")
polygon_plan = os.getenv("POLYGON_PLAN")
is_paid_polygon = polygon_plan == "paid"
is_realtime_polygon = polygon_plan == "realtime"

# REST の ラッパ

# 株式市場が開いているか（open / closed）を確認
def is_market_open() -> bool:
    client = RESTClient(polygon_api_key)
    market_status = client.get_market_status()
    return market_status.market == "open"

# SPY（S&P500 ETF）終値ベースの全銘柄データ取得
def get_all_share_prices_polygon_eod() -> dict[str, float]:
    """With much thanks to student Reema R. for fixing the timezone issue with this!"""
    # このタイムゾーンの問題を修正してくれた学生 Reema R. に深く感謝します。
    
    client = RESTClient(polygon_api_key)

    probe = client.get_previous_close_agg("SPY")[0]
    last_close = datetime.fromtimestamp(probe.timestamp / 1000, tz=timezone.utc).date()

    results = client.get_grouped_daily_aggs(last_close, adjusted=True, include_otc=False)
    return {result.ticker: result.close for result in results}

# キャッシュ付きで市場データを取得
@lru_cache(maxsize=2) # 同じ引数で再度呼び出したときに処理をスキップしキャッシュを返す
def get_market_for_prior_date(today):
    market_data = read_market(today)
    if not market_data:
        market_data = get_all_share_prices_polygon_eod()
        write_market(today, market_data)
    return market_data

# 株価取得（EOD = 終値ベース）
def get_share_price_polygon_eod(symbol) -> float:
    today = datetime.now().date().strftime("%Y-%m-%d")
    market_data = get_market_for_prior_date(today)
    return market_data.get(symbol, 0.0)

# 株価取得（分単位）
def get_share_price_polygon_min(symbol) -> float:
    client = RESTClient(polygon_api_key)
    result = client.get_snapshot_ticker("stocks", symbol)
    return result.min.close or result.prev_day.close

# プランに応じてデータソースを切替
def get_share_price_polygon(symbol) -> float:
    if is_paid_polygon:
        return get_share_price_polygon_min(symbol)
    else:
        return get_share_price_polygon_eod(symbol)

# （開発やデモ用の）フォールバック付き株価取得
def get_share_price(symbol) -> float:
    if polygon_api_key:
        try:
            return get_share_price_polygon(symbol)
        except Exception as e:
            # {e} のため polygon API を使用できませんでした。乱数を使用
            print(f"Was not able to use the polygon API due to {e}; using a random number")
    return float(random.randint(1, 100))
