#!/bin/bash

#
# A script to generate a "one-time CA" and exactly one server certificate
# signed by that CA and a Java keystore containing the certificate/key pair to
# be used with Java based servers.
#
# Modern browser tend to refuse storing sensitive information like passwords
# for sites not secured with a proper certificate. This can be annoying during
# development and test phase when using typical self-signed certificates.
#
# The idea of a "one-time CA" is that its root certificate can be safely
# imported into a browser. The CA is safe since no other certificate can be
# signed by that CA due to the fact that the CAs key is deleted right after
# signing exactly one server certificate.
#
# The "one-time CA", the certificate/key pair and the keystore should only be
# used for development and test purposes.
#
# Author: Dipl.-Ing. Robert C. Bonfig
#

#
# Copyright 2017-2021 Bonfig GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

C="DE"
O="Bonfig GmbH"

CA_NAME="bonfig-ca"
CA_SUBJECT="/C=$C/O=$O/CN=$O One Time CA $(date '+%Y-%m-%d')"

NAME="server"
SUBJECT="/C=$C/O=$O/CN=server"
SAN="DNS:localhost, IP:127.0.0.1, IP:0:0:0:0:0:0:0:1"

# Limit since 2020-09-01, see https://www.ssl.com/blogs/398-day-browser-limit-for-ssl-tls-certificates-begins-september-1-2020/
DAYS=398
PASS="password"

BUILD_DIR="build"

CA_KEY_PEM="$BUILD_DIR/$CA_NAME.key.pem"
CA_CRT_PEM="$BUILD_DIR/$CA_NAME.cert.pem"
CA_SRL="$BUILD_DIR/$CA_NAME.srl"

KEY_PEM="$BUILD_DIR/$NAME.key.pem"
CRT_CSR="$BUILD_DIR/$NAME.cert.csr"
CRT_PEM="$BUILD_DIR/$NAME.cert.pem"
CRT_P12="$BUILD_DIR/$NAME.cert.p12"

KEYSTORE="$BUILD_DIR/application.keystore"

OPENSSL="openssl"
KEYTOOL="keytool"

CONFIG="[req]
default_bits = 2048
default_md = sha512
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
req_extensions = v3_req
string_mask = utf8only

[req_distinguished_name]
countryName = Country Name (2 letter code)
0.organizationName = Organization Name
commonName = Common Name
 
[v3_ca]
basicConstraints = critical, CA:true, pathlen:0
subjectKeyIdentifier = hash
keyUsage = critical, keyCertSign

[v3_req]
subjectAltName = $SAN

[server_cert]
subjectAltName = $SAN
basicConstraints = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid, issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
nsCertType = server
nsComment = OpenSSL Generated Server Certificate " 

cd "$(dirname "$0")" || exit

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

# Create CA key and certificate
$OPENSSL req -x509 -newkey rsa:4096 -nodes -keyout $CA_KEY_PEM -out $CA_CRT_PEM -days $DAYS -config <(echo "$CONFIG") -subj "$CA_SUBJECT"
$OPENSSL x509 -text -noout -in $CA_CRT_PEM

# Create CSR for localhost
$OPENSSL req -newkey rsa:2048 -nodes -keyout $KEY_PEM -out $CRT_CSR -config <(echo "$CONFIG") -subj "$SUBJECT"
$OPENSSL req -text -noout -in $CRT_CSR

# Sign CSR
$OPENSSL x509 -req -in $CRT_CSR -CA $CA_CRT_PEM -CAkey $CA_KEY_PEM -CAcreateserial -out $CRT_PEM -days $DAYS -sha512 -extfile <(echo "$CONFIG") -extensions server_cert
$OPENSSL x509 -text -noout -in $CRT_PEM

# Combine certificate and key into pkcs12 keystore
$OPENSSL pkcs12 -inkey $KEY_PEM -in $CRT_PEM -export -name $NAME -out $CRT_P12 -passout pass:$PASS
$OPENSSL pkcs12 -info -noout -in $CRT_P12 -passin pass:$PASS

# Import pkcs12 keystore into Java keystore
$KEYTOOL -importkeystore -srckeystore $CRT_P12 -srcstoretype pkcs12 -srcstorepass $PASS -destkeystore $KEYSTORE -deststorepass $PASS -deststoretype pkcs12
$KEYTOOL -list -keystore $KEYSTORE -storepass $PASS

rm -f $CA_KEY_PEM $CA_SRL $CRT_CSR $CRT_P12
