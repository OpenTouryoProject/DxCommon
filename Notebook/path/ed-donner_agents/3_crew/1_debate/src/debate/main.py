#!/usr/bin/env python
import sys
import warnings

from datetime import datetime

from debate.crew import Debate

warnings.filterwarnings("ignore", category=SyntaxWarning, module="pysbd")

# runのみに削られている。

def run():
    """
    クルーを起動・実行する。
    """
    inputs = {
        'motion': 'LLMを規制するための厳格な法律が必要だ',
    }
    
    try:
        result = Debate().crew().kickoff(inputs=inputs)
        print(result.raw)
    except Exception as e:
        raise Exception(f"クルーの実行中にエラーが発生しました: {e}")
