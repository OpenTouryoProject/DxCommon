# MCPサーバーを簡単に立ち上げるクラス
from mcp.server.fastmcp import FastMCP
# MCPサーバーに変換したい元関数
from market import get_share_price

# accounts_server という名前のMCPサーバーを作成
mcp = FastMCP("market_server")

@mcp.tool()
async def lookup_share_price(symbol: str) -> float:
    """This tool provides the current price of the given stock symbol.

    Args:
        symbol: the symbol of the stock
    """
    return get_share_price(symbol)

if __name__ == "__main__":
    mcp.run(transport='stdio')