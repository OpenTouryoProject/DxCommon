using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Client.Options;
using System.Security.Cryptography.X509Certificates;

using Touryo.Infrastructure.Public.Util;

namespace MqttConfig
{
    /// <summary>Initial</summary>
    public class Initial
    {
        /// <summary>Initialize</summary>
        /// <param name="broker">string</param>
        /// <param name="topic">string</param>
        /// <param name="clientId">string</param>
        /// <param name="mqttClient">IMqttClient</param>
        /// <param name="mqttClientOptions">IMqttClientOptions</param>
        public static void Initialize(
            out string broker, out string topic, string clientId,
            out IMqttClient mqttClient, out IMqttClientOptions mqttClientOptions)
        {
            //  初期化
            Initial.InitConfig();
            Initial.GetConfigValues(
                out string mqttBrokerHostName, out int mqttBrokerPortNum, out topic,
                out string caCertPath, out string clientCertPath, out string clientCertPassword,
                out string userName, out string userPassword, out string val);

            broker = mqttBrokerHostName + ":" + mqttBrokerPortNum;
            clientId = clientId + "_" + val;

            // 証明書
            X509Certificate2 ca = new X509Certificate2(caCertPath);
            X509Certificate2 cli = new X509Certificate2(clientCertPath, clientCertPassword);

            MqttFactory factory = new MqttFactory();
            mqttClient = factory.CreateMqttClient();
            mqttClientOptions = new MqttClientOptionsBuilder()
                .WithClientId(clientId)
                .WithTcpServer(mqttBrokerHostName, mqttBrokerPortNum)
                .WithCredentials(userName, userPassword)
                .WithTls(new MqttClientOptionsBuilderTlsParameters()
                {
                    UseTls = true,
                    SslProtocol = System.Security.Authentication.SslProtocols.Tls12,
                    AllowUntrustedCertificates = true,
                    //CertificateValidationCallback = (a, b, c, d) => true,
                    CertificateValidationHandler = (o) =>
                    {
                        Console.WriteLine(o.ToString());
                        return true;
                    },
                    Certificates = new List<X509Certificate>()
                    {
                        ca, cli
                    }
                })
                .Build();
        }

        /// <summary>InitConfig</summary>
        private static void InitConfig()
        {
            string dir = new FileInfo(Assembly.GetExecutingAssembly().Location).Directory
                .FullName.Replace(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            GetConfigParameter.InitConfiguration(dir + "/appsettings.json");
        }

        /// <summary>GetConfigValue</summary>
        /// <param name="mqttBrokerHostName">string</param>
        /// <param name="mqttBrokerPortNum">int</param>
        /// <param name="topic">string</param>
        /// <param name="caCertPath">string</param>
        /// <param name="clientCertPath">string</param>
        /// <param name="clientCertPassword">string</param>
        /// <param name="userName">string</param>
        /// <param name="userPassword">string</param>
        /// <param name="clientId">string</param>
        private static void GetConfigValues(
            out string mqttBrokerHostName, out int mqttBrokerPortNum, out string topic,
            out string caCertPath, out string clientCertPath, out string clientCertPassword,
            out string userName, out string userPassword, out string clientId)
        {
            mqttBrokerHostName = GetConfigParameter.GetConfigValue("MSQT_HOST_NAME");
            mqttBrokerPortNum = int.Parse(GetConfigParameter.GetConfigValue("MSQT_PORT_NUM"));
            topic = GetConfigParameter.GetConfigValue("MSQT_TOPIC");
            caCertPath = GetConfigParameter.GetConfigValue("CA_CERT_PATH");
            clientCertPath = GetConfigParameter.GetConfigValue("CLIENT_CERT_PATH");
            clientCertPassword = GetConfigParameter.GetConfigValue("CLIENT_CERT_PASSWORD");
            userName = GetConfigParameter.GetConfigValue("USER_NAME");
            userPassword = GetConfigParameter.GetConfigValue("USER_PASSWORD");
            clientId = GetConfigParameter.GetConfigValue("CLIENT_ID");
        }
    }
}
