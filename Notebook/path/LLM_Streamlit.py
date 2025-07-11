from openai import OpenAI
import streamlit as st

# ページ設定
st.set_page_config(
    page_title="Ollama-Chatbot",
    page_icon="🤖",
    layout="wide",
)

# タイトルの表示
st.title("Chat with Ollama🤖")
st.caption("会話をリセットしたいときはページを再読み込みしてね。")

# OpenAIクライアントの設定
client = OpenAI(
    base_url='http://localhost:11434/v1/', # ローカル環境の場合
    # base_url='http://***.***.***.***:11434/v1/', # 別のPCから接続する場合（実際のIPアドレスを入力する）
    api_key='dummy' # ダミーでOK
    )

# LLMモデルの指定
chat_model = "llama3"

# 初期メッセージの設定
if "messages" not in st.session_state:
    st.session_state["messages"] = [
        # systemに役割を付与
        {"role": "system", "content": "You are an excellent AI Assistant. You must provide every answer in Japanese. よろしくね！"},
        # assistantのメッセージ
        {"role": "assistant", "content": f"こんにちは。私は{chat_model}です。 **何でも聞いてください。** "}
    ]

# 以前のメッセージを表示
for message in st.session_state.messages:
    # roleによってアバターを切り替える
    if message["role"] == "system":
        st.chat_message(message["role"], avatar='💻').write(message['content'])
    elif message["role"] == "assistant":
        st.chat_message(message["role"], avatar='🤖').write(message["content"])
    elif message["role"] == "user":
        st.chat_message(message["role"], avatar='👦').write(message["content"])

# ユーザーの入力後の処理
if prompt := st.chat_input("What is up?"):
    # ユーザーのメッセージを追加
    st.session_state.messages.append({"role": "user", "content": prompt})

    # ユーザーのメッセージを表示
    with st.chat_message("user", avatar='👦'):
        st.markdown(prompt)

    # チャットボットの返答を取得＆表示
    with st.chat_message("assistant", avatar='🤖'):
        # チャットボットの返答を取得
        stream = client.chat.completions.create(
            model=chat_model,
            messages=st.session_state.messages,
            stream=True,
        )
        # 返信をstreaming出力
        response = st.write_stream(stream)

    # メッセージに返答を追加
    st.session_state.messages.append({"role": "assistant", "content": response})
