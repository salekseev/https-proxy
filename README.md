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

The build stage compiles Nginx with a local OpenSSL key-log callback patch. Set `SSL_KEYLOG=false` at build time to skip the patch and compile entirely, keeping the stock distribution Nginx binary so the image follows distro security updates for Nginx; TLS key logging is then unavailable (see TLS Key Logging). The runtime generates certificates and configuration when the container starts.

### TLS Key Logging

TLS key logging is disabled by default. Set `SSL_KEY_LOGGING` to enable NSS/Wireshark-compatible TLS 1.2 and TLS 1.3 key logs at `/logs/ssl.log`:

```sh
docker run --rm -p 80:80 -p 443:443 \
  -e SSL_KEY_LOGGING=1 \
  -v "$PWD/logs:/logs" \
  v3rt3p-https-proxy
```

The variable's presence enables logging, including an empty value or `0`; omit it to disable logging. Restart the container after changing the environment. Existing log contents are preserved, and the file is restricted to mode `0600`. Key logging requires the patched Nginx binary: build with `docker build --build-arg SSL_KEYLOG=false` to skip the patch and the compile stage, in which case the image keeps the stock distribution Nginx (which receives distro security updates) and refuses to start if `SSL_KEY_LOGGING` is set.

Select `logs/ssl.log` as the TLS key log file in Wireshark. OpenSSL writes secrets immediately as they become available, without waiting for an HTTP request or for a connection to close. This includes handshakes with no HTTP traffic, long-lived connections, and failed handshakes that progressed far enough to derive secrets. Failures before key derivation cannot produce keys.

Both client-facing and upstream TLS handled by Nginx are logged, including stream TLS termination if configured. Unknown-domain TLS passthrough cannot be logged because Nginx does not participate in its handshake. Normal request logging remains on stdout. The patch registers the file with Nginx's log lifecycle, including reopen on `USR1`.

**Warning:** These secrets allow captured TLS traffic to be decrypted. Use only in authorized test environments, protect the mounted directory, and remove or rotate logs when testing is complete.
