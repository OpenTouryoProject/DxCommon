using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using RabbitMQ.Client;
using RabbitMQ.Client.Events;

using AmqpConfig;

namespace AmqpSubscriber
{
    public class Program
    {
        /// <summary>Main</summary>
        /// <param name="args">(string[]</param>
        public static void Main(string[] args)
        {
            //  初期化
            ConnectionFactory connectionFactory = Initial.Initialize(out string broker, out string topic);
            Console.WriteLine("Receiving messages to topic: " + topic + ", broker(s): " + broker);

            // Ctl+Cイベント定義
            Console.WriteLine("To stop a process running as subscriber, press [CTRL]-[C].");
            CancellationTokenSource tokenSource = new CancellationTokenSource();
            Console.CancelKeyPress += (_, e) =>
            {
                e.Cancel = true;
                tokenSource.Cancel(); // Taskキャンセル
            };

            Task cTask = Task.Run(() => new Action<ConnectionFactory, CancellationToken>((f, cancel) => {
                // コネクション＆チャンネル生成
                using (var conn = f.CreateConnection())
                using (var channel = conn.CreateModel())
                {
                    // Exchange生成
                    channel.ExchangeDeclare(topic, "fanout", false, true);

                    // Queue生成
                    var queueName = channel.QueueDeclare().QueueName;

                    // Bind Queue
                    channel.QueueBind(queueName, topic, "");

                    // コンシューマー生成
                    var consumer = new EventingBasicConsumer(channel);

                    // 受信イベント定義
                    consumer.Received += (_, ea) =>
                    {
                        Console.WriteLine(Encoding.UTF8.GetString(ea.Body.ToArray()));
                    };

                    // コンシューマー登録
                    channel.BasicConsume(queueName, true, consumer);

                    while (true)
                    {
                        // キャンセル待ち   
                        if (cancel.IsCancellationRequested)
                        {
                            break;
                        }
                    }
                }
            })(connectionFactory, tokenSource.Token), tokenSource.Token);

            Task.WaitAll(cTask);

            Console.WriteLine("stop .Net RabbitMQ Example. press any key to close.");
            Console.ReadKey();
        }
    }
}
