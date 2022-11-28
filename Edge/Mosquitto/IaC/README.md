# Simplest
This IaC is building Mosquitto as open-source MQTT broker.

### How to perform
Run the docker-compose up command in this directory.

- If you want to use MQTT over TLS, please rename the following file and use it.
  - docker-compose_8883.yaml
  - config/mosquitto_8883.conf

- The following client commands can be used to test.
  - MQTT
    - mosquitto_sub -h 127.0.0.1 -t "#" -v
    - mosquitto_pub -h 127.0.0.1 -t test -m "hoge"
  - MQTT over TLS
    - Server certificates
      - mosquitto_sub -h localhost -t "#" -v -d -p 8883 --cafile <path of ca.crt>
      - mosquitto_pub -h localhost -t test -m "hoge" -d -p 8883 --cafile <path of ca.crt>
    - Client certificate
      - mosquitto_sub -h localhost -t "#" -v -d -p 8883 --cafile <path of ca.crt> --cert <path of client.crt> --key <path of client.key> 
      - mosquitto_pub -h localhost -t test -m "hoge" -d -p 8883 --cafile <path of ca.crt> --cert <path of client.crt> --key <path of client.key> 

### Reference
- Mosquitto - マイクロソフト系技術情報 Wiki > 詳細 > その他の環境 > Docker on Windows
https://techinfoofmicrosofttech.osscons.jp/index.php?Mosquitto#ee39ea11
