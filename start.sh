#!/bin/sh
set -eu

if [ "${NGINX_ENTRYPOINT_LOCAL_RESOLVERS:-}" ]; then
    NGINX_LOCAL_RESOLVERS=$(awk 'BEGIN { ORS=" " } $1 == "nameserver" { if ($2 ~ /:/) print "[" $2 "]"; else print $2 }' /etc/resolv.conf)
    NGINX_LOCAL_RESOLVERS=${NGINX_LOCAL_RESOLVERS% }
    export NGINX_LOCAL_RESOLVERS
fi

envsubst '${NGINX_LOCAL_RESOLVERS}' \
    < /etc/nginx/templates/nginx.conf.template \
    > /etc/nginx/nginx.conf
rm -f /etc/nginx/conf.d/nginx.conf

/app/generate.sh

# Unknown HTTPS hosts need a certificate before an HTTP response can be sent.
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -nodes -days 365 -subj '/CN=localhost' \
    -keyout /app/generated/default.key -out /app/generated/default.crt
chmod 600 /app/generated/default.key

exec nginx -g 'daemon off;'
