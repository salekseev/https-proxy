#!/bin/sh
set -eu

# Render only startup settings; preserve all Nginx request variables.
if [ -z "${NGINX_LOCAL_RESOLVERS:-}" ]; then
    NGINX_LOCAL_RESOLVERS=$(awk 'BEGIN { ORS=" " } $1 == "nameserver" { if ($2 ~ /:/) print "[" $2 "]"; else print $2 }' /etc/resolv.conf)
    NGINX_LOCAL_RESOLVERS=${NGINX_LOCAL_RESOLVERS% }
fi
if [ -z "$NGINX_LOCAL_RESOLVERS" ]; then
    printf '%s\n' 'No DNS resolvers found in /etc/resolv.conf.' >&2
    exit 1
fi
export NGINX_LOCAL_RESOLVERS

NGINX_SSL_KEY_LOGGING=''
# Presence enables logging, even if the value is empty or "0".
if [ "${SSL_KEY_LOGGING+x}" = x ]; then
    # Keep files created during log rotation private as well.
    umask 077
    mkdir -p /logs
    touch /logs/ssl.log
    chmod 600 /logs/ssl.log
    NGINX_SSL_KEY_LOGGING='include /etc/nginx/templates/ssl-keylog.conf;'
fi
export NGINX_SSL_KEY_LOGGING

envsubst '${NGINX_LOCAL_RESOLVERS} ${NGINX_SSL_KEY_LOGGING}' \
    < /etc/nginx/templates/nginx.conf.template \
    > /etc/nginx/nginx.conf

/app/generate.sh
nginx -t
exec nginx -g 'daemon off;'
