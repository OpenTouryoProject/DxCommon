from crewai.tools import BaseTool
from typing import Type
from pydantic import BaseModel, Field

# crewAI で独自ツールを定義するサンプル・コード

class MyCustomToolInput(BaseModel):
    """MyCustomTool の入力スキーマ。"""
    argument: str = Field(..., description="引数の説明。")

class MyCustomTool(BaseTool):
    name: str = "ツールの名前"
    description: str = (
        "このツールが何に役立つかを明確に説明してください。エージェントがこのツールを使用するには、この情報が必要になります。"
    )
    args_schema: Type[BaseModel] = MyCustomToolInput

    def _run(self, argument: str) -> str:
        # 実装はここ
        return "これはツール出力の例なので、無視して先に進んでください。"
