openssl genrsa -out client.key 2048
openssl req -out client.csr -key client.key -new
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365
openssl pkcs12 -export -out client.pfx -inkey client.key -in client.crt