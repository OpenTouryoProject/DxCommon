import gradio as gr
from accounts import Account, get_share_price

# グローバルでアカウントを管理（1ユーザー想定）
account = None

def create_account(initial_deposit):
    global account
    try:
        account = Account(initial_deposit)
        return f"アカウントを作成しました。初期入金額: ￥{initial_deposit:,}", gr.update(interactive=True), gr.update(interactive=True), gr.update(interactive=True), gr.update(interactive=True)
    except Exception as e:
        return f"エラー: {str(e)}", gr.update(interactive=False), gr.update(interactive=False), gr.update(interactive=False), gr.update(interactive=False)

def deposit_funds(amount):
    global account
    try:
        account.deposit(amount)
        return f"￥{amount:,} を入金しました。現在残高: ￥{account.balance:,}"
    except Exception as e:
        return f"エラー: {str(e)}"

def withdraw_funds(amount):
    global account
    try:
        account.withdraw(amount)
        return f"￥{amount:,} を出金しました。現在残高: ￥{account.balance:,}"
    except Exception as e:
        return f"エラー: {str(e)}"

def buy_shares(symbol, quantity):
    global account
    try:
        price = get_share_price(symbol)
        account.buy_shares(symbol, quantity)
        total = price * quantity
        return f"{symbol.upper()} を {quantity} 株購入しました（価格: ￥{price:,} x {quantity} ＝ ￥{total:,}）\n残高: ￥{account.balance:,}"
    except Exception as e:
        return f"エラー: {str(e)}"

def sell_shares(symbol, quantity):
    global account
    try:
        price = get_share_price(symbol)
        account.sell_shares(symbol, quantity)
        total = price * quantity
        return f"{symbol.upper()} を {quantity} 株売却しました（価格: ￥{price:,} x {quantity} ＝ ￥{total:,}）\n残高: ￥{account.balance:,}"
    except Exception as e:
        return f"エラー: {str(e)}"

def show_portfolio():
    global account
    if not account:
        return "アカウントが未作成です。"
    holdings = account.get_holdings()
    portfolio_lines = []
    total = 0
    for symbol, qty in holdings.items():
        price = get_share_price(symbol)
        val = price * qty
        portfolio_lines.append(f"{symbol}: {qty}株 × ￥{price:,} = ￥{val:,}")
        total += val
    if not portfolio_lines:
        return "現在、保有株式はありません。"
    msg = "\n".join(portfolio_lines) + f"\n合計時価評価額: ￥{total:,}\n残高: ￥{account.balance:,}"
    return msg

def show_profit_and_loss():
    global account
    if not account:
        return "アカウントが未作成です。"
    pnl = account.calculate_profit_and_loss()
    return f"損益（現時点）: ￥{pnl:,.0f}"

def show_trade_history():
    global account
    if not account:
        return "アカウントが未作成です。"
    history = account.get_trade_history()
    lines = []
    for entry in history:
        if entry["type"] == "deposit":
            lines.append(f"入金: ￥{entry['amount']:,}")
        elif entry["type"] == "withdraw":
            lines.append(f"出金: ￥{entry['amount']:,}")
        elif entry["type"] == "buy":
            lines.append(f"購入: {entry['symbol']} {entry['quantity']}株 @￥{entry['price']:,}/株 (合計￥{entry['total']:,})")
        elif entry["type"] == "sell":
            lines.append(f"売却: {entry['symbol']} {entry['quantity']}株 @￥{entry['price']:,}/株 (合計￥{entry['total']:,})")
    if not lines:
        return "取引履歴はありません。"
    return "\n".join(lines)

with gr.Blocks(title="シンプル取引シミュレーションUI") as demo:
    gr.Markdown("## 取引シミュレータ アカウント管理デモ\n1人ユーザー・シンプル操作のみ")
    # アカウント作成
    with gr.Row():
        init_deposit = gr.Number(label="初期入金額", value=100000, interactive=True)
        create_btn = gr.Button("アカウント作成")
    creation_result = gr.Textbox(label="ステータス", max_lines=2)
    
    # 入出金（未作成時は非活性）
    with gr.Row():
        deposit_amt = gr.Number(label="入金額", value=0, interactive=False)
        deposit_btn = gr.Button("入金", interactive=False)
    deposit_result = gr.Textbox(label="入金結果", max_lines=2)
    with gr.Row():
        withdraw_amt = gr.Number(label="出金額", value=0, interactive=False)
        withdraw_btn = gr.Button("出金", interactive=False)
    withdraw_result = gr.Textbox(label="出金結果", max_lines=2)
    
    # 売買（未作成時は非活性）
    with gr.Row():
        symbol_choices = ['AAPL', 'TSLA', 'GOOGL']
        buy_symbol = gr.Dropdown(choices=symbol_choices, label="購入シンボル", value="AAPL", interactive=False)
        buy_qty = gr.Number(label="購入株数", value=1, interactive=False)
        buy_btn = gr.Button("購入", interactive=False)
    buy_result = gr.Textbox(label="購入結果", max_lines=2)
    
    with gr.Row():
        sell_symbol = gr.Dropdown(choices=symbol_choices, label="売却シンボル", value="AAPL", interactive=False)
        sell_qty = gr.Number(label="売却株数", value=1, interactive=False)
        sell_btn = gr.Button("売却", interactive=False)
    sell_result = gr.Textbox(label="売却結果", max_lines=2)
    
    # 保有・損益・履歴
    portfolio_btn = gr.Button("保有資産を表示")
    portfolio_result = gr.Textbox(label="保有資産内容", max_lines=10)
    pnl_btn = gr.Button("損益を表示")
    pnl_result = gr.Textbox(label="損益", max_lines=2)
    history_btn = gr.Button("取引履歴表示")
    history_result = gr.Textbox(label="取引履歴", max_lines=10)
    
    # イベント紐付け
    create_btn.click(
        create_account, 
        inputs=[init_deposit], 
        outputs=[
            creation_result,
            deposit_amt, withdraw_amt, buy_symbol, buy_qty
        ]
    )
    deposit_btn.click(deposit_funds, inputs=deposit_amt, outputs=deposit_result)
    withdraw_btn.click(withdraw_funds, inputs=withdraw_amt, outputs=withdraw_result)
    buy_btn.click(buy_shares, inputs=[buy_symbol, buy_qty], outputs=buy_result)
    sell_btn.click(sell_shares, inputs=[sell_symbol, sell_qty], outputs=sell_result)
    portfolio_btn.click(lambda: show_portfolio(), outputs=portfolio_result)
    pnl_btn.click(lambda: show_profit_and_loss(), outputs=pnl_result)
    history_btn.click(lambda: show_trade_history(), outputs=history_result)

if __name__ == "__main__":
    demo.launch()