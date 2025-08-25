import logging
import queue
import threading
import time
import gradio as gr
from deal_agent_framework import DealAgentFramework
from agents.deals import Opportunity, Deal
from log_utils import reformat
import plotly.graph_objects as go

# 標準の logging を log_queue と result_queue と繋いで、ログを UI 側に流す仕組み

# バックグラウンドで走るエージェントのログを 非同期に UI に反映
class QueueHandler(logging.Handler):
    def __init__(self, log_queue):
        super().__init__()
        self.log_queue = log_queue

    def emit(self, record):
        self.log_queue.put(self.format(record))

# ログ表示のHTML整形（背景色を暗くしたスクロール可能なログ表示領域）
def html_for(log_data):
    output = '<br>'.join(log_data[-18:])
    return f"""
    <div id="scrollContent" style="height: 400px; overflow-y: auto; border: 1px solid #ccc; background-color: #222229; padding: 10px;">
    {output}
    </div>
    """

# 標準の logging を初期化
def setup_logging(log_queue):
    handler = QueueHandler(log_queue)
    formatter = logging.Formatter(
        "[%(asctime)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S %z",
    )
    handler.setFormatter(formatter)
    logger = logging.getLogger()
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
                
# 取引探索エージェントの活動を、ログ＋テーブル＋ベクトル空間可視化で表示するWeb UIアプリ
class App:

    # 初期化（取引探索エージェント未設定
    def __init__(self):    
        self.agent_framework = None

    # 取引探索エージェントを設定
    def get_agent_framework(self):
        if not self.agent_framework:
            self.agent_framework = DealAgentFramework()
            self.agent_framework.init_agents_as_needed()
        return self.agent_framework

    # 全体を実行
    def run(self):

        # UI定義
        with gr.Blocks(title="The Price is Right", fill_width=True) as ui:
            
            log_data = gr.State([])

            # Opportunity オブジェクト群を DataFrame 表示用のリストに変換
            def table_for(opps):
                return [[opp.deal.product_description, f"${opp.deal.price:.2f}", f"${opp.estimate:.2f}", f"${opp.discount:.2f}", opp.deal.url] for opp in opps]
            
            # Gradio でのリアルタイム更新（タイマー起動）
            # ・log_data : 現在のログリスト（HTML表示用に保持）
            # ・log_queue : バックグラウンド処理からのログメッセージキュー
            # ・result_queue : バックグラウンド処理の最終結果を格納するキュー
            def update_output(log_data, log_queue, result_queue):
                
                # 既存の Opportunitise をテーブル形式に変換
                initial_result = table_for(self.get_agent_framework().memory)

                # バックグラウンド処理で得られる Opportunitise
                final_result = None
                
                # 無限ループでのポーリング
                while True:
                    try:
                        # log_queue をチェックし、あれば取得。
                        message = log_queue.get_nowait()
                        
                        # データのリストに追加（reformatは整形）
                        log_data.append(reformat(message))
                        
                        # Gradio に3つの出力を返す：
                        # log_data → 状態保持用（gr.State）
                        # html_for(log_data) → ログ表示用HTML
                        # final_result or initial_result → テーブル表示
                        yield log_data, html_for(log_data), final_result or initial_result
                        
                    except queue.Empty: # log_queueが空で queue.Empty が発生した場合
                        try:
                            # result_queue をチェックし、あれば取得。
                            final_result = result_queue.get_nowait()
                            # Gradio に3つの出力を返す（既出）
                            yield log_data, html_for(log_data), final_result or initial_result
                        except queue.Empty: # result_queue が空で queue.Empty が発生した場合
                            if final_result is not None: # 一回でも取れた場合
                                break                    # ループを抜け処理を完了させる
                            time.sleep(0.1)              # 一回でも取れてない場合

            # 3Dプロットの初期ダミー表示用
            def get_initial_plot():
                fig = go.Figure()
                fig.update_layout(
                    title='Loading vector DB...',
                    height=400,
                )
                return fig

            # 3Dプロットの実際の表示用
            def get_plot():
                documents, vectors, colors = DealAgentFramework.get_plot_data(max_datapoints=1000)
                # Create the 3D scatter plot
                fig = go.Figure(data=[go.Scatter3d(
                    x=vectors[:, 0],
                    y=vectors[:, 1],
                    z=vectors[:, 2],
                    mode='markers',
                    marker=dict(size=2, color=colors, opacity=0.7),
                )])
                
                fig.update_layout(
                    scene=dict(xaxis_title='x', 
                               yaxis_title='y', 
                               zaxis_title='z',
                               aspectmode='manual',
                               aspectratio=dict(x=2.2, y=2.2, z=1),  # Make x-axis twice as long
                               camera=dict(
                                   eye=dict(x=1.6, y=1.6, z=0.8)  # Adjust camera position
                               )),
                    height=400,
                    margin=dict(r=5, b=1, l=5, t=2)
                )

                return fig

            # 処理の本体（取引探索エージェントの実行）
            def do_run():
                new_opportunities = self.get_agent_framework().run()
                table = table_for(new_opportunities)
                return table

            # 処理の本体のログ設定（UI側からタイマーで起動）
            def run_with_logging(initial_log_data):
                # log_queue と result_queue を作成し setup_logging
                log_queue = queue.Queue()
                result_queue = queue.Queue()
                setup_logging(log_queue)

                # 処理の本体を別スレッドで実行
                def worker():
                    result = do_run()
                    result_queue.put(result)
                
                thread = threading.Thread(target=worker)
                thread.start()

                # update_output() がログや結果を随時 yield して UI に反映。
                for log_data, output, final_result in update_output(initial_log_data, log_queue, result_queue):
                    yield log_data, output, final_result

            # ユーザー操作ハンドラ（DataFrame の行をクリックすると Opportunity を取り出し通知）
            def do_select(selected_index: gr.SelectData):
                opportunities = self.get_agent_framework().memory
                row = selected_index.index[0]
                opportunity = opportunities[row]
                self.get_agent_framework().planner.messenger.alert(opportunity)

            # UI：１行目
            with gr.Row():
                gr.Markdown(
                    #'<div style="text-align: center;font-size:24px"><strong>The Price is Right</strong> - Autonomous Agent Framework that hunts for deals</div>'
                    '<div style="text-align: center;font-size:24px"><strong>価格は適正</strong> - 取引を探す自律エージェントフレームワーク</div>'
                )
            
            # UI：２行目
            with gr.Row():
                gr.Markdown(
                    #'<div style="text-align: center;font-size:14px">A proprietary fine-tuned LLM deployed on Modal and a RAG pipeline with a frontier model collaborate to send push notifications with great online deals.</div>'
                    '<div style="text-align: center;font-size:14px">Modal にデプロイされた独自の微調整された LLM と、フロンティア モデルを備えた RAG パイプラインが連携して、素晴らしいオンライン セールのプッシュ通知を送信します。</div>'
                )
                
            # UI：３行目
            with gr.Row():
                opportunities_dataframe = gr.Dataframe(
                    headers=[
                        #"Deals found so far", "Price", "Estimate", "Discount", "URL"
                        "説明", "価格", "見積", "割引", "URL"
                    ],
                    wrap=True,
                    column_widths=[6, 1, 1, 1, 3],
                    row_count=10,
                    col_count=5,
                    max_height=400,
                )
            # UI：４行目
            with gr.Row():
                # UI：４行目１列はログ
                with gr.Column(scale=1):
                    logs = gr.HTML()
                # UI：４行目１列はプロット
                with gr.Column(scale=1):
                    plot = gr.Plot(value=get_plot(), show_label=False)
        
            # UI初期処理で、処理の本体をタイマーで起動するよう仕掛ける
            ui.load(run_with_logging, inputs=[log_data], outputs=[log_data, logs, opportunities_dataframe])
            timer = gr.Timer(value=300, active=True)
            timer.tick(run_with_logging, inputs=[log_data], outputs=[log_data, logs, opportunities_dataframe])

            # イベントハンドラを仕掛ける
            opportunities_dataframe.select(do_select)
        
        # UI表示
        ui.launch(share=False, inbrowser=True)

# スクリプトとして直接実行された場合、全体を実行
if __name__=="__main__":
    App().run()
    