import os
from typing import Dict

import resend # import sendgrid
#from sendgrid.helpers.mail import Mail, Email, To, Content
from agents import Agent, function_tool

@function_tool
def send_email(subject: str, html_body: str) -> Dict[str, str]:
    """ Send out an email with the given subject and HTML body """
    
    #sg = sendgrid.SendGridAPIClient(api_key=os.environ.get('SENDGRID_API_KEY'))
    resend.api_key=os.getenv("RESEND_API_KEY")
    
    #from_email = Email("ed@edwarddonner.com")  # 検証済みの送信者に変更します
    #to_email = To("ed.donner@gmail.com")  # 受信者に変更します
    #content = Content("text/html", html_body)
    #mail = Mail(from_email, to_email, subject, content).get()
    #sg.client.mail.send.post(request_body=mail)
    
    response = resend.Emails.send({
        "from": "onboarding@resend.dev",
        "to": "nishi_74322014@ksj.biglobe.ne.jp",
        "subject": subject,
        "html": html_body
    })

    return {"status": "success"}

INSTRUCTIONS = """You are able to send a nicely formatted HTML email based on a detailed report.
You will be provided with a detailed report. You should use your tool to send one email, providing the 
report converted into clean, well presented HTML with an appropriate subject line."""

email_agent = Agent(
    name="Email agent",
    instructions=INSTRUCTIONS,
    tools=[send_email],
    model="gpt-4o-mini",
)
