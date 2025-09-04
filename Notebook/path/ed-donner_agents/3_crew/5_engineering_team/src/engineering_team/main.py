#!/usr/bin/env python
import sys
import warnings
import os
from datetime import datetime

from engineering_team.crew import EngineeringTeam

warnings.filterwarnings("ignore", category=SyntaxWarning, module="pysbd")

# Create output directory if it doesn't exist
os.makedirs('output', exist_ok=True)

requirements = """
- 取引シミュレーションプラットフォーム用のシンプルなアカウント管理システム。
- システムは、ユーザーがアカウントを作成し、資金を入金および出金できるようにする必要があります。
- システムは、ユーザーが株式の売買を記録し、数量を提供する必要があります。
- システムは、ユーザーのポートフォリオの合計額と、初期入金からの損益を計算する必要があります。
- システムは、いつでもユーザーの保有資産を報告できる必要があります。
- システムは、いつでもユーザーの損益を報告できる必要があります。
- システムは、ユーザーが行った取引を時間の経過とともに一覧表示できる必要があります。
- システムは、ユーザーがマイナス残高になるような資金の引き出し、または購入可能な株式数を超えて株式を購入したり、保有していない株式を売却したりすることを防ぐ必要があります。
- システムは、株式の現在の価格を返す関数 get_share_price(symbol) にアクセスでき、AAPL、TSLA、GOOGL の固定価格を返すテスト実装が含まれています。
"""
module_name = "accounts.py"
class_name = "Account"

def run():
    """
    Run the research crew.
    """
    inputs = {
        'requirements': requirements,
        'module_name': module_name,
        'class_name': class_name
    }

    # Create and run the crew
    result = EngineeringTeam().crew().kickoff(inputs=inputs)

if __name__ == "__main__":
    run()