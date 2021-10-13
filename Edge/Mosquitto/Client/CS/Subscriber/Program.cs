using System;
using System.Text;
using System.Threading.Tasks;
using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Client.Options;

using MqttConfig;

namespace MqttSubscriber
{
    public class Program
    {
        /// <summary>Main</summary>
        /// <param name="args">(string[]</param>
        /// <returns>Task</returns>
        public static async Task Main(string[] args)
        {
            //  初期化
            Initial.Initialize(
                out string broker, out string topic, "MqttSubscriber",
                out IMqttClient mqttClient, out IMqttClientOptions mqttClientOptions);

            // 接続後のイベント・ハンドラの設定
            // 接続の完了
            mqttClient.UseConnectedHandler(async e =>
            {
                // → Subscribe
                await mqttClient.SubscribeAsync(
                    new MqttTopicFilterBuilder().WithTopic(topic).Build());
            });
            // メッセージの受信
            mqttClient.UseApplicationMessageReceivedHandler(e =>
            {
                Console.WriteLine(Encoding.UTF8.GetString(e.ApplicationMessage.Payload));
            });

            // 接続
            await mqttClient.ConnectAsync(mqttClientOptions);
            
            Console.WriteLine("Receiving messages to topic: " + topic + ", broker(s): " + broker);
            Console.WriteLine("To stop a process running as subscriber, press [CTRL]-[C].");
            
            // 待機
            Console.ReadLine();
        }
    }
}
