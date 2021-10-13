using RabbitMQ.Client;
using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using AmqpConfig;

namespace AmqpPublisher
{
    public class Program
    {
        /// <summary>Main</summary>
        /// <param name="args">(string[]</param>
        static void Main(string[] args)
        {
            //  初期化
            ConnectionFactory connectionFactory = Initial.Initialize(out string broker, out string topic);
            Console.WriteLine("Sending messages to topic: " + topic + ", broker(s): " + broker);

            // Ctl+Cイベント定義
            Console.WriteLine("To stop a process running as publisher, press [CTRL]-[C].");
            CancellationTokenSource tokenSource = new CancellationTokenSource();
            Console.CancelKeyPress += (_, e) =>
            {
                e.Cancel = true;
                tokenSource.Cancel(); // Taskキャンセル
            };

            Task pTask = Task.Run(() => new Action<ConnectionFactory, CancellationToken>((f, cancel) => {
                // コネクション＆チャンネル生成
                using (IConnection conn = f.CreateConnection())
                using (IModel channel = conn.CreateModel())
                {
                    // Exchange生成
                    channel.ExchangeDeclare(topic, "fanout", false, true);

                    int x = 0;
                    while (true)
                    {
                        // キャンセル待ち
                        if (cancel.IsCancellationRequested)
                        {
                            break;
                        }

                        string msg = string.Format("Sample message #{0} sent at {1}", x, DateTime.Now.ToString("yyyy-MM-dd_HH:mm:ss.ffff"));

                        // Publish!!
                        try
                        {
                            channel.BasicPublish(topic, "", null, Encoding.UTF8.GetBytes(msg));
                            Console.WriteLine(string.Format("Message {0} sent (value: '{1}')", x, msg));
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"failer send. reason: {ex.Message}");
                        }

                        Thread.Sleep(1000);
                        x++;
                    }
                }
            })(connectionFactory, tokenSource.Token), tokenSource.Token);

            Task.WaitAll(pTask);

            Console.WriteLine("stop .Net RabbitMQ Example. press any key to close.");
            Console.ReadKey();
        }
    }
}
