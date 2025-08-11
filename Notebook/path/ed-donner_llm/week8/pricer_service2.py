import modal
from modal import App, Volume, Image # Volumeを追加

# Setup - define our infrastructure with code!

# Modal上のアプリに “pricer-service” と名所付与
app = modal.App("pricer-service")
# DebianベースのSlimコンテナに、huggingface、torch, transformers, bitsandbytes, accelerate, peft を pip install
image = Image.debian_slim().pip_install("huggingface", "torch", "transformers", "bitsandbytes", "accelerate", "peft") # huggingfaceを追加
# modal.com の Secrets に設定した HF_TOKEN を読込
secrets = [modal.Secret.from_name("hf-secret")]

# Constants

# GPU のラインナップから T4 を選択する。# T4, L4, A10, A100 ...
GPU = "T4"
# AutoModelForCausalLM.from_pretrainedでHugging Faceから読み込むLLM
BASE_MODEL = "meta-llama/Meta-Llama-3.1-8B"

# 以下はLoRAファインチューニングの結果
PROJECT_NAME = "pricer"
HF_USER = "ed-donner"
RUN_NAME = "2024-09-13_13.04.39"
PROJECT_RUN_NAME = f"{PROJECT_NAME}-{RUN_NAME}"
REVISION = "e8d637df551603dc86cd7a1598a8f44af4d7ae36"
FINETUNED_MODEL = f"{HF_USER}/{PROJECT_RUN_NAME}"

# 以下：追加の定数・変数
CACHE_DIR = "/cache"
MIN_CONTAINERS = 0 # 常時起動は "1"、そうでない場合は 2分後に停止
hf_cache_volume = Volume.from_name("hf-hub-cache", create_if_missing=True)

# 以下：関数中から移動した定数・変数
QUESTION = "How much does this cost to the nearest dollar?"
PREFIX = "Price is $"

# ステートフルにするので、関数からクラスに設計変更
@app.cls(
    image=image.env({"HF_HUB_CACHE": CACHE_DIR}),
    secrets=secrets, 
    gpu=GPU, 
    timeout=1800,
    min_containers=MIN_CONTAINERS,
    volumes={CACHE_DIR: hf_cache_volume}
)
class Pricer:

    @modal.enter()
    def setup(self):
        import torch
        from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, set_seed
        from peft import PeftModel
        
        # ファインチューニングしたモデルで製品価格を予測（第7週の内容）
                
        # Quant Config で 4bit量子化
        quant_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_quant_type="nf4"
        )

        # Load model and tokenizer
        
        # トークナイザ
        self.tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
        
        # padトークン → モデルのeos_token（文章終了）で代用
        self.tokenizer.pad_token = self.tokenizer.eos_token
        # 右パディング → 生成時に効率的
        self.tokenizer.padding_side = "right"
        
        # Baseモデル
        self.base_model = AutoModelForCausalLM.from_pretrained(
            BASE_MODEL, 
            quantization_config=quant_config,
            device_map="auto"
        )

        # FTedモデル
        self.fine_tuned_model = PeftModel.from_pretrained(self.base_model, FINETUNED_MODEL, revision=REVISION)

    @modal.method()
    def price(self, description: str) -> float:
        import os
        import re
        import torch
        from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, set_seed
        from peft import PeftModel
    
        # 完全再現性あり（シード固定）
        set_seed(42)

        # プロンプトを合成
        prompt = f"{QUESTION}\n\n{description}\n\n{PREFIX}"

        # エンコード
        inputs = self.tokenizer.encode(prompt, return_tensors="pt").to("cuda")
        
        # すべての入力トークンを有効化（torch.onesで全1）
        attention_mask = torch.ones(inputs.shape, device="cuda")
        # プロンプトの後続を、最大5トークンだけ生成、生成結果は1つ。
        outputs = self.fine_tuned_model.generate(inputs, attention_mask=attention_mask, max_new_tokens=5, num_return_sequences=1)

        # デコード
        result = self.tokenizer.decode(outputs[0])
    
        # 数値部分のみ抜き出し
        contents = result.split("Price is $")[1]
        contents = contents.replace(',','')
        match = re.search(r"[-+]?\d*\.\d+|\d+", contents)

        return float(match.group()) if match else 0