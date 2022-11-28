using System;
using System.IO;
using System.Reflection;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

using RabbitMQ.Client;

using Touryo.Infrastructure.Public.Util;

namespace AmqpConfig
{
    /// <summary>Initial</summary>
    public class Initial
    {
        /// <summary>Initialize</summary>
        /// <param name="broker">string</param>
        /// <param name="topic">string</param>
        /// <returns>ConnectionFactory</returns>
        public static ConnectionFactory Initialize(out string amqpBrokerHostName, out string topic)
        {
            //  初期化
            Initial.InitConfig();
            Initial.GetConfigValues(
                out amqpBrokerHostName, out topic,
                out string caCertPath, out string clientCertPath, out string clientCertPassword,
                out string userName, out string userPassword);

            X509Certificate2 cli = new X509Certificate2(clientCertPath, clientCertPassword);

            // ファクトリ生成
            ConnectionFactory connectionFactory = new ConnectionFactory()
            {
                HostName = amqpBrokerHostName,
                //UserName = userName,
                //Password = userPassword,
                AuthMechanisms = new IAuthMechanismFactory[] { new ExternalMechanismFactory() },
                Ssl = new SslOption
                {
                    Enabled = true,
                    ServerName = amqpBrokerHostName,
                    AcceptablePolicyErrors = SslPolicyErrors.RemoteCertificateNameMismatch
                                             | SslPolicyErrors.RemoteCertificateChainErrors,
                    Certs = new X509CertificateCollection(new X509Certificate[] { cli })
                }
            };

            return connectionFactory;
        }

        /// <summary>InitConfig</summary>
        private static void InitConfig()
        {
            string dir = new FileInfo(Assembly.GetExecutingAssembly().Location).Directory
                .FullName.Replace(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            GetConfigParameter.InitConfiguration(dir + "/appsettings.json");
        }

        /// <summary>GetConfigValue</summary>
        /// <param name="amqpBrokerHostName">string</param>
        /// <param name="topic">string</param>
        /// <param name="caCertPath">string</param>
        /// <param name="clientCertPath">string</param>
        /// <param name="clientCertPassword">string</param>
        /// <param name="userName">string</param>
        /// <param name="userPassword">string</param>
        private static void GetConfigValues(
            out string amqpBrokerHostName, out string topic,
            out string caCertPath, out string clientCertPath, out string clientCertPassword,
            out string userName, out string userPassword)
        {
            amqpBrokerHostName = GetConfigParameter.GetConfigValue("RBMQ_HOST_NAME");
            topic = GetConfigParameter.GetConfigValue("RBMQ_TOPIC");
            caCertPath = GetConfigParameter.GetConfigValue("CA_CERT_PATH");
            clientCertPath = GetConfigParameter.GetConfigValue("CLIENT_CERT_PATH");
            clientCertPassword = GetConfigParameter.GetConfigValue("CLIENT_CERT_PASSWORD");
            userName = GetConfigParameter.GetConfigValue("USER_NAME");
            userPassword = GetConfigParameter.GetConfigValue("USER_PASSWORD");
        }
    }
}
