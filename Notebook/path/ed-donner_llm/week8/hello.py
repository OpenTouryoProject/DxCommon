import modal
from modal import App, Image

# Setup

# Modal上のアプリに “hello” と名所付与
app = modal.App("hello")
# DebianベースのSlimコンテナに、requests を pip install
image = Image.debian_slim().pip_install("requests")

# Hello!

# ipinfo.ioはIPアドレスを調査する手軽で安定性したAPI

# hello
# 上記コンテナ・イメージで関数を実行するよう指定
@app.function(image=image)
def hello() -> str:
    import requests

    # https://ipinfo.io/json にHTTP GET
    response = requests.get('https://ipinfo.io/json')
    # response.json()から
    data = response.json()
    # city, region, country を取り出し
    city, region, country = data['city'], data['region'], data['country']
    # "Hello from ..." の文字列を返す
    return f"Hello from {city}, {region}, {country}!!"

# New - added thanks to student Tue H.!

# hello_europe
# 上記コンテナ・イメージで関数を実行するよう指定
# また、実行リージョンをヨーロッパに固定する。
@app.function(image=image, region="eu")
def hello_europe() -> str:
    import requests

    # https://ipinfo.io/json にHTTP GET
    response = requests.get('https://ipinfo.io/json')
    # response.json()から
    data = response.json()
    # city, region, country を取り出し
    city, region, country = data['city'], data['region'], data['country']
    # "Hello from ..." の文字列を返す
    return f"Hello from {city}, {region}, {country}!!"
