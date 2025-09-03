#!/usr/bin/env python
import sys
import warnings

from datetime import datetime

from jp_crew.crew import JpCrew

warnings.filterwarnings("ignore", category=SyntaxWarning, module="pysbd")

# このエントリーポイント・スクリプトは jp_crew パッケージの JpCrew クラスを呼び出して、
# エージェントのチーム（crew）を4種類のモード（実行・学習・再現・テスト）でローカル実行するためのもの。
# このメインファイルは、ローカルでチームを実行するためのものです。不要なロジックを追加しないでください。
# テストに使用する入力に置き換えると、タスクとエージェントの情報が自動的に補間されます。

# 目的: チームを起動してタスクを実行。
# 入力: topic（テーマ）と current_year（実行年）。
# 呼び出し先: kickoff → 実際にプロジェクト（エージェント群）が動き出す。
def run():
    """
    クルーを起動・実行する。
    """
    inputs = {
        'topic': 'AI LLMs',
        'current_year': str(datetime.now().year)
    }
    
    try:
        JpCrew().crew().kickoff(inputs=inputs)
    except Exception as e:
        raise Exception(f"クルーの実行中にエラーが発生しました: {e}")

# 目的: チームを指定回数トレーニング。
# 入力: コマンドラインから受け取る
# - sys.argv[1] → 学習反復回数
# - sys.argv[2] → 学習結果を保存するファイル名
def train():
    """
    指定された回数だけクルーを訓練
    """
    inputs = {
        "topic": "AI LLMs",
        'current_year': str(datetime.now().year)
    }
    try:
        JpCrew().crew().train(n_iterations=int(sys.argv[1]), filename=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"クルーの訓練中にエラーが発生しました: {e}")

# 目的: 特定のタスクからチーム実行を再現。
# 入力: sys.argv[1] → 再現対象のタスクID。
def replay():
    """
    特定のタスクからクルーの実行を再生します。
    """
    try:
        JpCrew().crew().replay(task_id=sys.argv[1])

    except Exception as e:
        raise Exception(f"クルーの再生中にエラーが発生しました {e}")

# 目的: テスト用の実行を行い、結果を評価。
# 入力: コマンドラインから受け取る
# - sys.argv[1] → テスト反復回数
# - sys.argv[2] → 評価に使うLLMの指定（例: "gpt-4"）
def test():
    """
    クルーの実行をテストし、結果を返します。
    """
    inputs = {
        "topic": "AI LLMs",
        "current_year": str(datetime.now().year)
    }
    
    try:
        JpCrew().crew().test(n_iterations=int(sys.argv[1]), eval_llm=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"クルーのテスト中にエラーが発生しました: {e}")
