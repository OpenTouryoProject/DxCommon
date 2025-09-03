from crewai.tools import BaseTool
from typing import Type
from pydantic import BaseModel, Field
import os
import requests

# プッシュ通知の送信データ
class PushNotification(BaseModel):
    """ユーザーに送信するメッセージ"""
    message: str = Field(..., description="ユーザーに送信されるメッセージ。")

# プッシュ通知の送信ツール
class PushNotificationTool(BaseTool):
    
    # ツールのメタデータ
    name: str = "プッシュ通知を送信する"
    description: str = (
        "このツールは、ユーザーにプッシュ通知を送信するために使用されます。"
    )

    # 引数スキーマ
    args_schema: Type[BaseModel] = PushNotification

    # ツールの実行
    def _run(self, message: str) -> str:

        # ログ
        print(f"Push: {message}")

        # 環境変数からPushoverのユーザーIDとトークンを取得
        pushover_user = os.getenv("PUSHOVER_USER")
        pushover_token = os.getenv("PUSHOVER_TOKEN")

        # 送信するペイロード
        payload = {"user": pushover_user, "token": pushover_token, "message": message}

        # Pushover APIのURLにPOSTリクエストを送信
        pushover_url = "https://api.pushover.net/1/messages.json"
        requests.post(pushover_url, data=payload)

        # 結果
        return '{"notification": "ok"}'