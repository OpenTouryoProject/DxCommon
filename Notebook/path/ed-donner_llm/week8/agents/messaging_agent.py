import os
# from twilio.rest import Client
from agents.deals import Opportunity
import http.client
import urllib
from agents.agent import Agent

# Uncomment the Twilio lines if you wish to use Twilio
# Twilio を使用する場合は、Twilio の行のコメントを解除します

DO_TEXT = False # Twilio
DO_PUSH = True  # Pushover

# メッセージ通知のエージェント
class MessagingAgent(Agent):

    name = "Messaging Agent"
    color = Agent.WHITE

    # 初期化
    def __init__(self):
        """
        Set up this object to either do push notifications via Pushover, or SMS via Twilio, whichever is specified in the constants.
        このオブジェクトの定数で指定されたとおりに、Pushover 経由でプッシュ通知を実行するか、Twilio 経由で SMS を送信するかのいずれかを行います。
        """

        # Messaging Agentの初期化中
        self.log(f"Messaging Agent is initializing")
        
        if DO_TEXT:
            account_sid = os.getenv('TWILIO_ACCOUNT_SID', 'your-sid-if-not-using-env')
            auth_token = os.getenv('TWILIO_AUTH_TOKEN', 'your-auth-if-not-using-env')
            self.me_from = os.getenv('TWILIO_FROM', 'your-phone-number-if-not-using-env')
            self.me_to = os.getenv('MY_PHONE_NUMBER', 'your-phone-number-if-not-using-env')
            # self.client = Client(account_sid, auth_token)

            # Messaging Agentの準備が完了 Twilio
            self.log("Messaging Agent has initialized Twilio")
            
        if DO_PUSH:
            self.pushover_user = os.getenv('PUSHOVER_USER', 'your-pushover-user-if-not-using-env')
            self.pushover_token = os.getenv('PUSHOVER_TOKEN', 'your-pushover-user-if-not-using-env')

            # Messaging Agentの準備が完了 Pushover
            self.log("Messaging Agent has initialized Pushover")

    # メッセージ送信 Twilio
    def message(self, text):
        """
        Send an SMS message using the Twilio API
        Twilio APIを使用してSMSメッセージを送信する
        """

        # Messaging Agentがテキストメッセージを送信します。
        self.log("Messaging Agent is sending a text message")
        
        message = self.client.messages.create(
          from_=self.me_from,
          body=text,
          to=self.me_to
        )

    # プッシュ通知 Pushover 
    def push(self, text):
        """
        Send a Push Notification using the Pushover API
        Pushover APIを使用してプッシュ通知を送信する
        """

        # Messaging Agentがプッシュ通知を送信します。
        self.log("Messaging Agent is sending a push notification")
        
        conn = http.client.HTTPSConnection("api.pushover.net:443")
        conn.request("POST", "/1/messages.json",
          urllib.parse.urlencode({
            "token": self.pushover_token,
            "user": self.pushover_user,
            "message": text,
            "sound": "cashregister"
          }), { "Content-type": "application/x-www-form-urlencoded" })
        conn.getresponse()

    # 商談アラートの発行
    def alert(self, opportunity: Opportunity):
        """
        Make an alert about the specified Opportunity
        指定された商談についてアラートを発する
        """

        # opportunityオブジェクトから通知文を作成
        # 価格・推定値・割引・商品の短い説明・URLをまとめた短い通知文
        text = f"Deal Alert! Price=${opportunity.deal.price:.2f}, "
        text += f"Estimate=${opportunity.estimate:.2f}, "
        text += f"Discount=${opportunity.discount:.2f} :"
        text += opportunity.deal.product_description[:10]+'... '
        text += opportunity.deal.url
        
        if DO_TEXT:
            # メッセージ送信 Twilio
            self.message(text)
        if DO_PUSH:
            # プッシュ通知 Pushover 
            self.push(text)

        # Messaging Agentがアラート送信を完了
        self.log("Messaging Agent has completed")
        
    
        