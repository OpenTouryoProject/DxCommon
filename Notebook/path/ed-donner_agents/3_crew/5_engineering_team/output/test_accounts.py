import pytest
from accounts import Account, get_share_price

def test_get_share_price_valid():
    assert get_share_price('AAPL') == 180.0
    assert get_share_price('tsla') == 750.0
    assert get_share_price('GOOGL') == 2825.0

def test_get_share_price_invalid():
    with pytest.raises(ValueError):
        get_share_price('MSFT')

def test_account_initialization():
    acc = Account(1000)
    assert acc.initial_deposit == 1000.0
    assert acc.balance == 1000.0
    assert acc.holdings == {}
    assert acc.trade_history == []
    
    with pytest.raises(ValueError):
        Account(-100)

def test_account_deposit():
    acc = Account(500)
    acc.deposit(250)
    assert acc.balance == 750.0
    assert acc.trade_history[-1]['type'] == 'deposit'
    assert acc.trade_history[-1]['amount'] == 250
    
    with pytest.raises(ValueError):
        acc.deposit(0)
    with pytest.raises(ValueError):
        acc.deposit(-50)

def test_account_withdraw():
    acc = Account(100)
    acc.withdraw(50)
    assert acc.balance == 50.0
    assert acc.trade_history[-1]['type'] == 'withdraw'
    
    with pytest.raises(ValueError):
        acc.withdraw(0)
    with pytest.raises(ValueError):
        acc.withdraw(-30)
    with pytest.raises(ValueError):
        acc.withdraw(300)

def test_account_buy_shares():
    acc = Account(10000)
    acc.buy_shares('AAPL', 10)
    assert acc.holdings['AAPL'] == 10
    assert acc.balance == 10000 - 180.0*10
    assert acc.trade_history[-1]['type'] == 'buy'
    
    with pytest.raises(ValueError):
        acc.buy_shares('AAPL', 0)
    with pytest.raises(ValueError):
        acc.buy_shares('GOOGL', 100)
    with pytest.raises(ValueError):
        acc.buy_shares('FAKE', 1)

def test_account_sell_shares():
    acc = Account(10000)
    acc.buy_shares('TSLA', 8)
    acc.sell_shares('TSLA', 5)
    assert acc.holdings['TSLA'] == 3
    assert acc.trade_history[-1]['type'] == 'sell'
    
    acc.sell_shares('TSLA', 3)
    assert 'TSLA' not in acc.holdings
    
    with pytest.raises(ValueError):
        acc.sell_shares('TSLA', 1)
    with pytest.raises(ValueError):
        acc.sell_shares('AAPL', 1)
    with pytest.raises(ValueError):
        acc.sell_shares('TSLA', 0)
    with pytest.raises(ValueError):
        acc.sell_shares('TSLA', -2)

def test_account_portfolio_value():
    acc = Account(10000)
    assert acc.calculate_portfolio_value() == 0.0
    acc.buy_shares('AAPL', 4)
    acc.buy_shares('TSLA', 2)
    expected = 4*180.0 + 2*750.0
    assert acc.calculate_portfolio_value() == expected

def test_account_profit_and_loss():
    acc = Account(5000)
    # 何もしてなければ損益0
    assert acc.calculate_profit_and_loss() == 0.0
    # 購入
    acc.buy_shares('AAPL', 5)   # 900
    acc.buy_shares('TSLA', 2)   # 1500
    # 残高 = 5000-900-1500=2600, 評価 = 5*180+2*750=900+1500=2400
    # P&L = 2600+2400-5000 = 0
    assert acc.calculate_profit_and_loss() == 0.0
    acc.sell_shares('AAPL', 5)  # +900現金化，評価額-900
    # 残高=2600+900=3500, 保有:TSLA2, 評価1500, P&L=(3500+1500-5000=0)
    assert acc.calculate_profit_and_loss() == 0.0

def test_get_holdings_and_trade_history():
    acc = Account(1000)
    acc.buy_shares('AAPL', 2)
    acc.deposit(100)
    acc.sell_shares('AAPL', 1)
    h = acc.get_holdings()
    assert h == {'AAPL':1}
    hist = acc.get_trade_history()
    assert len(hist) == 3