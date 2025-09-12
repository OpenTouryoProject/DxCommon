import asyncio

from autogen_ext.runtimes.grpc import GrpcWorkerAgentRuntimeHost
from autogen_ext.runtimes.grpc import GrpcWorkerAgentRuntime
from autogen_core import AgentId

import messages
from agent import Agent
from creator import Creator

HOW_MANY_AGENTS = 10 #20

# メッセージの送信
async def create_and_message(worker, creator_id, i: int):
    try:
        # メッセージはエージェント名を表す、agent{i}.py になり、
        result = await worker.send_message(messages.Message(content=f"agent{i}.py"), creator_id)
        
        # エージェントに対応する応答は、idea{i}.md になる。
        with open(f"idea{i}.md", "w") as f:
            f.write(result.content)
            
    except Exception as e:
        print(f"Failed to run worker {i} due to exception: {e}")

# エントリ・ポイントから実行されるmain関数
async def main():

    # 開始
    host = GrpcWorkerAgentRuntimeHost(address="localhost:50051")
    host.start() 
    worker = GrpcWorkerAgentRuntime(host_address="localhost:50051")
    await worker.start()

    # Creatorを登録
    result = await Creator.register(worker, "Creator", lambda: Creator("Creator"))
    creator_id = AgentId("Creator", "default")

    # ｎ回の非同期呼出
    coroutines = [create_and_message(worker, creator_id, i) for i in range(1, HOW_MANY_AGENTS+1)]
    await asyncio.gather(*coroutines)

    # 停止
    try:
        await worker.stop()
        await host.stop()
    except Exception as e:
        print(e)

# エントリ・ポイント
if __name__ == "__main__":
    asyncio.run(main())
