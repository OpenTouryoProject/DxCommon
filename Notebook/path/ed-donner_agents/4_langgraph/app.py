import gradio as gr
from sidekick import Sidekick

# Graph（エージェント・システム）の初期化
async def setup():
    sidekick = Sidekick()
    await sidekick.setup()
    return sidekick

# process_message → run_superstep
# sidekick は `4_lab4.ipynb`版の thread を包含
async def process_message(sidekick, message, success_criteria, history):
    results = await sidekick.run_superstep(message, success_criteria, history)
    return results, sidekick

# thread_idの初期化はSidekickのコンストラクタに入っている。
async def reset():
    new_sidekick = Sidekick()
    await new_sidekick.setup()
    return "", "", None, new_sidekick

# cleanupのラッパーで、(UIのSession)State破棄時に呼ばれる。
def free_resources(sidekick):
    print("Cleaning up")
    try:
        if sidekick:
            sidekick.cleanup()
    except Exception as e:
        print(f"Exception during cleanup: {e}")

# Sidekick UI
with gr.Blocks(title="Sidekick", theme=gr.themes.Default(primary_hue="emerald")) as ui:
    gr.Markdown("## Sidekick Personal Co-Worker")

    # 先ずは、(UIのSession)State破棄時のクリーナップ・コードだけを指定（初期値は後からセット）
    sidekick = gr.State(delete_callback=free_resources)
    
    # UI立上毎に(UIのSession)State初期化。コレは、sidekick = setup([]) みたいな意味。
    ui.load(setup, [], [sidekick])
    
    # 各種UI要素
    with gr.Row():
        chatbot = gr.Chatbot(label="Sidekick", height=300, type="messages")
    with gr.Group():
        with gr.Row():
            message = gr.Textbox(show_label=False, placeholder="Your request to the Sidekick")
        with gr.Row():
            success_criteria = gr.Textbox(
                show_label=False, placeholder="What are your success critiera?"
            )
    with gr.Row():
        reset_button = gr.Button("Reset", variant="stop")
        go_button = gr.Button("Go!", variant="primary")

    # イベント・ハンドラ
    message.submit(process_message, [sidekick, message, success_criteria, chatbot], [chatbot, sidekick])
    success_criteria.submit(process_message, [sidekick, message, success_criteria, chatbot], [chatbot, sidekick])
    go_button.click(process_message, [sidekick, message, success_criteria, chatbot], [chatbot, sidekick])
    reset_button.click(reset, [], [message, success_criteria, chatbot, sidekick])

ui.launch(inbrowser=True)
