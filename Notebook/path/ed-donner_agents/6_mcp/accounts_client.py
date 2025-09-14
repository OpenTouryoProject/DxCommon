import json

# MCPプロトコル
import mcp
# 標準入出力(STDIO)のMCPクライアント
from mcp.client.stdio import stdio_client
# 標準入出力(STDIO)のMCPクライアントのパラメタ
from mcp import StdioServerParameters

# OpenAI Agents SDK の FunctionTool
from agents import FunctionTool

# 標準入出力(STDIO)のMCPクライアントとしてMCPサーバ起動
params = StdioServerParameters(command="uv", args=["run", "accounts_server.py"], env=None)

# accounts MCPサーバのツールの一覧を取得する関数
async def list_accounts_tools():
    async with stdio_client(params) as streams:
        async with mcp.ClientSession(*streams) as session:
            await session.initialize()
            tools_result = await session.list_tools()
            return tools_result.tools
            
# accounts MCPサーバのツールを呼出す関数
async def call_accounts_tool(tool_name, tool_args):
    async with stdio_client(params) as streams:
        async with mcp.ClientSession(*streams) as session:
            await session.initialize()
            result = await session.call_tool(tool_name, tool_args)
            return result

# サーバー上のリソースを読込関数（アカウント情報）
async def read_accounts_resource(name):
    async with stdio_client(params) as streams:
        async with mcp.ClientSession(*streams) as session:
            await session.initialize()
            result = await session.read_resource(f"accounts://accounts_server/{name}")
            return result.contents[0].text
        
# サーバー上のリソースを読込関数（戦略情報）
async def read_strategy_resource(name):
    async with stdio_client(params) as streams:
        async with mcp.ClientSession(*streams) as session:
            await session.initialize()
            result = await session.read_resource(f"accounts://strategy/{name}")
            return result.contents[0].text

# OpenAI向けツール変換関数
async def get_accounts_tools_openai():
    openai_tools = []
    for tool in await list_accounts_tools():
        schema = {**tool.inputSchema, "additionalProperties": False}
        openai_tool = FunctionTool(
            name=tool.name,
            description=tool.description,
            params_json_schema=schema,
            on_invoke_tool=lambda ctx, args, toolname=tool.name: call_accounts_tool(toolname, json.loads(args))
                
        )
        openai_tools.append(openai_tool)
    return openai_tools