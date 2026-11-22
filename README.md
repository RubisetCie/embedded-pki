<h1 style="text-align:center">Embedded PKI</h1>

A collection of **Bash scripts** to form a **portable PKI** via OpenSSL.

## Getting started

First, create a root CA:

```
./create_root_ca.sh my_root_ca
```

It will create directory structure. Then, you may edit the **OpenSSL configuration file** in the following directory: *my_root_ca/configs/openssl.cnf*.

The next step consists in initializing the root CA by creating a root certificate:

```
./initialize_root_ca.sh my_root_ca
```

You can specify some certificate generation parameters:

```
./initialize_root_ca.sh --key-type RSA --rsa-bits 4096 --digest SHA512 my_root_ca
```

After the initialization, you can issue certificates through the scripts located in the root CA directories (e.g: *my_root_ca/scripts/create_cert.sh*):

```
./my_root_ca/scripts/create_cert.sh my_certificate
```

All the certificates are located under the following directory: *my_root_ca/data*.

## Documentation

The scripts to interact with root certificates are the following:

|  Script name            | Description                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------- |
| `create_root_ca.sh`     | Create a root CA                                                                        |
| `delete_root_ca.sh`     | Delete a root CA                                                                        |
| `list_root_ca.sh`       | List all the created root CA                                                            |
| `initialize_root_ca.sh` | Initialize a root CA by creating a certificate and private key                          |
| `reset_root_ca.sh`      | Reset a root CA to an uninitialized state (removing all issued certificates and sub CA) |
| `new_root_ca.sh`        | An alias to `create_root_ca.sh`                                                         |
| `remove_root_ca.sh`     | An alias to `delete_root_ca.sh`                                                         |
| `clean_root_ca.sh`      | An alias to `reset_root_ca.sh`                                                          |

The scripts to interact with certificates inside of a root CA are the following:

|  Script name              | Description                                                                      |
| ------------------------- | -------------------------------------------------------------------------------- |
| `create_cert.sh`          | Create a new certificate issued by the CA, alongside with its private key        |
| `create_cert_from_csr.sh` | Create a new certificate issued by the CA, from a provided signing request (CSR) |
| `create_sub_ca.sh`        | Create a new certificate issued by the CA, to form the base of a new sub CA      |
| `generate_crl.sh`         | Generate a certificate revocation list (CRL) from revoked certificates           |
| `revoke_cert.sh`          | Revoke a certificate issued by the CA                                            |
| `print_cert.sh`           | Print the info / details of a certificate                                        |
| `dump_cert.sh`            | Print the PEM data of a certificate                                              |
| `dump_cert_chain.sh`      | Print the PEM data of a certificate, including its issuer(s) chain               |
| `new_cert.sh`             | An alias to `create_cert.sh`                                                     |
| `new_cert_from_csr.sh`    | An alias to `create_cert_from_csr.sh`                                            |
| `new_sub_ca.sh`           | An alias to `create_sub_ca.sh`                                                   |

For each script, you may use the `--help` option to print out their respective usages and options.

For some scripts, you may use the `--list` option to display the supported algorithms, ciphers, digests, etc, depending on your local OpenSSL installation.
