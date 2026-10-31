# https-proxy

HTTPS reverse-proxy server for use with **v3rt3p** software that relies on the eMudhra intermediate CA with broken keys.

The proxy generates elliptic-curve certificates for configured domains, serves HTTP and HTTPS endpoints with Nginx, and forwards requests to the upstream host specified by each domain list and passes unchanged anything else.

## Layout

```text
.
├── certs/
│   ├── ca.crt
│   └── ca.key
├── domains/
│   ├── yandex.txt
│   ├── vk.txt
│   └── sber.txt
├── generated/
│   ├── certs/
│   │   └── <list-name>/
│   │       ├── <domain>.chain.crt
│   │       └── <domain>.key
│   └── configs/
│       ├── yandex.conf
│       ├── vk.conf
│       └── sber.conf
├── Dockerfile
├── generate.sh
└── nginx.conf
```

`generated/` is rebuilt by the generator and is ignored by Git.

## Domain Lists

Each file in `domains/` uses this format:

```text
upstream.example
service.example
another-service.example
```

- The first line is the upstream hostname.
- Every following non-empty, non-comment line is a domain to proxy.
- For a domain named `service.example`, requests are forwarded to:

```text
http://upstream.example/service.example$request_uri
```

For example, `domains/yandex.txt` starts with `yandex.ru`, so each listed domain is proxied through `yandex.ru`.

## Generate Locally

The generator requires OpenSSL and creates P-384 elliptic-curve keys and certificate chains:

```sh
./generate.sh
```

Generated output is placed under:

```text
generated/certs/<list-name>/<domain>.chain.crt
generated/certs/<list-name>/<domain>.key
generated/configs/<list-name>.conf
```

Each generated Nginx config contains both an HTTP server on port 80 and an HTTPS server on port 443. WebSocket upgrade headers are enabled for both protocols.

## Docker

Build the multistage image from the repository root:

```sh
docker build -t v3rt3p-https-proxy .
```

Run it with ports 80 and 443 published:

```sh
docker run --rm -p 80:80 -p 443:443 v3rt3p-https-proxy
```

The build stage runs `generate.sh`. The final image contains Nginx and the generated runtime files, but does not contain OpenSSL, the source domain lists, the generator script, or the CA private key.
