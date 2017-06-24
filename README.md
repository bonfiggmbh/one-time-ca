# one-time-ca

A script to generate a _one-time CA_ and exactly one server certificate signed by that CA and a Java keystore containing the certificate/key pair to be used with Java based servers.

Modern browser tend to refuse storing sensitive information like passwords for sites not secured with a proper certificate. This can be annoying during development and test phase when using typical self-signed certificates.

The idea of a _one-time CA_ is that its root certificate can be safely imported into a browser. The CA is safe since no other certificate can be signed by that CA due to the fact that the CAs key is deleted right after signing exactly one server certificate.

The _one-time CA_, the certificate/key pair and the keystore should only be used for development and test purposes.