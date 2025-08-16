import logging

# エージェント抽象クラス
class Agent:
    """
    An abstract superclass for Agents used to log messages in a way that can identify each Agent.
    各エージェントを識別できる方法でメッセージを記録するために使用されるエージェントの抽象スーパークラス。
    """

    ########################
    # ANSI カラーコードの定義
    ########################
    # Foreground colors
    # 前景色
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Background color
    # 背景色
    BG_BLACK = '\033[40m'
    
    # Reset code to return to default color
    # デフォルトの色に戻すためのリセット・コード
    RESET = '\033[0m'

    ########################
    # クラス変数
    ########################
    # エージェント名（例：Planning Agent）
    name: str = ""
    # そのエージェントの前景色（初期値は白）
    color: str = '\033[37m'

    # 自分の名前と色付きのログ出力
    def log(self, message):
        """
        Log this as an info message, identifying the agent
        これを情報メッセージとして記録し、エージェントを識別します
        """
        color_code = self.BG_BLACK + self.color
        # ログメッセージの先頭に [エージェント名] をつける
        message = f"[{self.name}] {message}"
        # ログ出力（ANSIエスケープシーケンスで色を制御）
        logging.info(color_code + message + self.RESET)