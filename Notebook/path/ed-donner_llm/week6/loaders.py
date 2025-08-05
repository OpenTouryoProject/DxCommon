"""
要するにこのクラスは大規模データ前提で高速に効率よくアイテムリストを生成する
Amazonレビューから、商品情報を (1) 価格でフィルタ、(2) 有効かどうかチェック、
 (3) Itemへ加工、 (4) 結果をパラレル化で高速処理、 (5) カテゴリを振って出力
"""

from datetime import datetime                                          # 実行時間の計測用
from tqdm import tqdm                                                  # 進捗バー表示用
from datasets import load_dataset                                      # HF Datasetsで読込
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor # 並列処理（複数プロセスで高速化）
from items import Item                                                 # 独自定義のItemクラス

# 一度に処理するデータ件数/価格フィルター条件
CHUNK_SIZE = 1000
MIN_PRICE = 0.5
MAX_PRICE = 999.49

# Amazonレビューから有効な商品（価格範囲などで絞り込み）を抽出する汎用クラス。
class ItemLoader:

    # カテゴリ名を記録、datasetオブジェクト初期化
    def __init__(self, name):
        self.name = name
        self.dataset = None

    # from_chunkから呼び出され、データ1件毎にItemインスタンスを生成
    def from_datapoint(self, datapoint):
        """
        Try to create an Item from this datapoint. Return the Item if successful, or None if it shouldn't be included.
        このデータポイントからアイテムを作成してみてください。成功した場合はアイテムを返し、含まれていない場合はNoneを返します。
        """
        try:
            price_str = datapoint['price']
            if price_str:
                price = float(price_str)
                if MIN_PRICE <= price <= MAX_PRICE:
                    item = Item(datapoint, price)
                    return item if item.include else None
        except ValueError:
            return None

    # chunk（データのまとまり、最大1000件）毎に、from_datapoint() する。
    def from_chunk(self, chunk):
        """
        Create a list of Items from this chunk of elements from the Dataset
        データセットの要素のチャンクからアイテムのリストを作成
        """
        batch = []
        for datapoint in chunk:
            result = self.from_datapoint(datapoint)
            if result:
                batch.append(result)
        return batch

    # データセット全体をCHUNK_SIZEずつに分割してイテレータで返す
    def chunk_generator(self):
        """
        Iterate over the Dataset, yielding chunks of datapoints at a time
        データセットを反復処理し、一度にデータポイントのチャンクを生成
        """
        size = len(self.dataset)
        for i in range(0, size, CHUNK_SIZE):
            yield self.dataset.select(range(i, min(i + CHUNK_SIZE, size)))

    # load() から呼び出される並列読み込み関数
    def load_in_parallel(self, workers):
        """
        Use concurrent.futures to farm out the work to process chunks of datapoints -
        This speeds up processing significantly, but will tie up your computer while it's doing so!
        大量のデータポイントを処理する作業を外部委託するには、concurrent.futures を使用。
        これにより処理速度は大幅に向上しますが、その間はコンピューターが拘束される。
        """
        results = []
        chunk_count = (len(self.dataset) // CHUNK_SIZE) + 1
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for batch in tqdm(pool.map(self.from_chunk, self.chunk_generator()), total=chunk_count):
                results.extend(batch)
        for result in results:
            result.category = self.name
        return results

    # データセットの読込関数
    def load(self, workers=8):
        """
        Load in this dataset; the workers parameter specifies how many processes
        should work on loading and scrubbing the data
        """
        start = datetime.now()
        print(f"Loading dataset {self.name}", flush=True)
        self.dataset = load_dataset("McAuley-Lab/Amazon-Reviews-2023", f"raw_meta_{self.name}", split="full", trust_remote_code=True)
        results = self.load_in_parallel(workers)
        finish = datetime.now()
        print(f"Completed {self.name} with {len(results):,} datapoints in {(finish-start).total_seconds()/60:.1f} mins", flush=True)
        return results