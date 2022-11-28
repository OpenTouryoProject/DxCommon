# certs
Use the following BAT to generate the broker's certificate.

Points to consider when entering data.
- Entering the 'extra' attributes is not required.
- The password that was input pfx file generation is used from within the program.
- When the CN (Common Name) of the certifications are the same, an error occurs when connecting.

### 1_ca.bat
```
writing new private key to 'ca.key'
Enter PEM pass phrase:xxxxx
Verifying - Enter PEM pass phrase:xxxxx
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:JP
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:hogeca
Email Address []:
```

### 2_server.bat
```
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:JP
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:localhost
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

```
Signature ok
subject=C = JP, ST = Some-State, O = Internet Widgits Pty Ltd, CN = localhost
Getting CA Private Key
Enter pass phrase for ca.key:
```

### 3_client.bat

```
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:JP
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:hogecli
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

```
Signature ok
subject=C = AU, ST = Some-State, O = Internet Widgits Pty Ltd, CN = hogecli
Getting CA Private Key
Enter pass phrase for ca.key:
```

```
Enter Export Password:xxxxx
Verifying - Enter Export Password:xxxxx
```
