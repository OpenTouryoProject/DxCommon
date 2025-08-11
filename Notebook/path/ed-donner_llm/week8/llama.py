import modal
from modal import App, Volume, Image

# Setup

# Modal上のアプリに “llama” と名所付与
app = modal.App("llama")
# DebianベースのSlimコンテナに、torch, transformers, bitsandbytes, accelerate を pip install
image = Image.debian_slim().pip_install("torch", "transformers", "bitsandbytes", "accelerate")
# modal.com の Secrets に設定した HF_TOKEN を読込
secrets = [modal.Secret.from_name("hf-secret")]

# Constants

# GPU のラインナップから T4 を選択する。# T4, L4, A10, A100 ...
GPU = "T4"
# AutoModelForCausalLM.from_pretrainedでHugging Faceから読み込むLLM
MODEL_NAME = "meta-llama/Meta-Llama-3.1-8B" # "google/gemma-2-2b"

# 上記コンテナ・イメージで関数を実行するよう指定
@app.function(image=image, secrets=secrets, gpu=GPU, timeout=1800)
def generate(prompt: str) -> str:
    import os
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, set_seed

    # 4bit量子化されたLLMを使って、プロンプトの後続を、最大5トークンだけ新規生成（第7週の内容）
    
    # Quant Config で 4bit量子化
    quant_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_quant_type="nf4"
    )

    # Load model and tokenizer

    # トークナイザ
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    
    # padトークン → モデルのeos_token（文章終了）で代用
    tokenizer.pad_token = tokenizer.eos_token
    # 右パディング → 生成時に効率的
    tokenizer.padding_side = "right"

    # モデル
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME, 
        quantization_config=quant_config,
        device_map="auto"
    )

    # 完全再現性あり（シード固定）
    set_seed(42)

    # エンコード
    inputs = tokenizer.encode(prompt, return_tensors="pt").to("cuda")
    
    # すべての入力トークンを有効化（torch.onesで全1）
    attention_mask = torch.ones(inputs.shape, device="cuda")
    # プロンプトの後続を、最大5トークンだけ生成、生成結果は1つ。
    outputs = model.generate(inputs, attention_mask=attention_mask, max_new_tokens=5, num_return_sequences=1)
    
    # デコード
    return tokenizer.decode(outputs[0])