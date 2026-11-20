using System;
using System.Threading;
using System.Threading.Tasks;
using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Client.Options;

using MqttConfig;

namespace MqttPublisher
{
    public class Program
    {
        /// <summary>bool</summary>
        static private bool loop = true;

        /// <summary>Main</summary>
        /// <param name="args">(string[]</param>
        /// <returns>Task</returns>
        static async Task Main(string[] args)
        {
            //  初期化
            Initial.Initialize(
                out string broker,  out string topic, "MqttPublisher",
                out IMqttClient mqttClient, out IMqttClientOptions mqttClientOptions);

            // 接続
            await mqttClient.ConnectAsync(mqttClientOptions);

            Console.WriteLine("Sending messages to topic: " + topic + ", broker(s): " + broker);
            Console.WriteLine("To stop a process running as publisher, press [CTRL]-[C].");

            int x = 0;
            while (Program.loop)
            {
                string msg = string.Format("Sample message #{0} sent at {1}", x, DateTime.Now.ToString("yyyy-MM-dd_HH:mm:ss.ffff"));

                // メッセージ送信の設定
                MqttApplicationMessage message = new MqttApplicationMessageBuilder()
                    .WithTopic(topic)
                    .WithPayload(msg)
                    .WithExactlyOnceQoS()
                    .Build();

                // メッセージの送信 publish
                await mqttClient.PublishAsync(message);

                Console.WriteLine(string.Format("Message {0} sent (value: '{1}')", x, msg));

                Thread.Sleep(1000);
                x++;
            }
        }
    }
}
