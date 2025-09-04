def get_share_price(symbol: str) -> float:
    """
    指定された株式シンボルの現在価格（テスト用固定値）を返す。
    """
    prices = {
        'AAPL': 180.0,
        'TSLA': 750.0,
        'GOOGL': 2825.0,
    }
    symbol = symbol.upper()
    if symbol in prices:
        return prices[symbol]
    raise ValueError(f"価格取得不可なシンボル: {symbol}")

class Account:
    def __init__(self, initial_deposit: float):
        """
        アカウント新規作成/初期化し、初期入金額を登録。
        保有資産（株数）/全取引履歴/残高を初期化。
        """
        if initial_deposit < 0:
            raise ValueError("初期入金額は0以上でなければなりません。")
        self.initial_deposit = float(initial_deposit)
        self.balance = float(initial_deposit)
        self.holdings = {}
        self.trade_history = []

    def deposit(self, amount: float):
        """
        資金をアカウントに入金
        """
        if amount <= 0:
            raise ValueError("入金額は0より大きくなければなりません。")
        self.balance += amount
        self.trade_history.append({
            'type': 'deposit',
            'amount': amount
        })

    def withdraw(self, amount: float):
        """
        残高から資金を出金。
        出金後にマイナスになる場合はエラー。
        """
        if amount <= 0:
            raise ValueError("出金額は0より大きくなければなりません。")
        if self.balance < amount:
            raise ValueError("残高不足です。")
        self.balance -= amount
        self.trade_history.append({
            'type': 'withdraw',
            'amount': amount
        })

    def buy_shares(self, symbol: str, quantity: int):
        """
        シンボルの株式をquantity分購入。
        必要な残高がなければエラー。
        """
        if quantity <= 0:
            raise ValueError("購入数量は1以上である必要があります。")
        symbol = symbol.upper()
        price = get_share_price(symbol)
        total_cost = price * quantity
        if self.balance < total_cost:
            raise ValueError("株式購入のための残高が不足しています。");
        self.balance -= total_cost
        self.holdings[symbol] = self.holdings.get(symbol, 0) + quantity
        self.trade_history.append({
            'type': 'buy',
            'symbol': symbol,
            'quantity': quantity,
            'price': price,
            'total': total_cost
        })

    def sell_shares(self, symbol: str, quantity: int):
        """
        シンボルの株式をquantity分売却。
        保有株数以上売れない。売却後保有ゼロなら保持リストから削除。
        """
        symbol = symbol.upper()
        if quantity <= 0:
            raise ValueError("売却数量は1以上である必要があります。")
        held = self.holdings.get(symbol, 0)
        if held < quantity:
            raise ValueError("保有株数が不足しています。");
        price = get_share_price(symbol)
        total_value = price * quantity
        self.holdings[symbol] = held - quantity
        if self.holdings[symbol] == 0:
            del self.holdings[symbol]
        self.balance += total_value
        self.trade_history.append({
            'type': 'sell',
            'symbol': symbol,
            'quantity': quantity,
            'price': price,
            'total': total_value
        })

    def calculate_portfolio_value(self) -> float:
        """
        現在保有銘柄（株式）の合計評価額を算出。
        """
        total = 0.0
        for symbol, qty in self.holdings.items():
            price = get_share_price(symbol)
            total += price * qty
        return total

    def calculate_profit_and_loss(self) -> float:
        """
        現在の損益（残高＋時価評価 - 初期入金額）
        """
        return self.balance + self.calculate_portfolio_value() - self.initial_deposit

    def get_holdings(self) -> dict:
        """
        現在の保有株式（シンボル→株数辞書）
        """
        return dict(self.holdings)

    def get_trade_history(self) -> list:
        """
        取引履歴のリストを返す
        """
        return list(self.trade_history)

# テストやUI構築用に何も自動実行せずここで終了