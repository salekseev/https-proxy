# SSL_KEYLOG=true (default) compiles Nginx with the OpenSSL key-log callback
# patch. SSL_KEYLOG=false keeps the stock distribution Nginx binary, skips the
# compile stage entirely, and the image then follows distro security updates
# for Nginx; TLS key logging is unavailable in that build.
ARG SSL_KEYLOG=true

FROM nginx:1.27-alpine AS nginx-build
ARG SSL_KEYLOG=true
COPY patches/nginx-sslkeylog-1.27.patch /build/sslkeylog.patch
RUN if [ "$SSL_KEYLOG" = true ]; then \
        apk add --no-cache build-base linux-headers openssl-dev pcre2-dev zlib-dev curl patch \
        && mkdir -p /build/nginx \
        && curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
            | tar -xz -C /build/nginx --strip-components=1 \
        && cd /build/nginx \
        && patch -p1 < /build/sslkeylog.patch \
        && configure_args=$(nginx -V 2>&1 | sed -n 's/^configure arguments: //p') \
        && eval "./configure $configure_args" \
        && make -j"$(getconf _NPROCESSORS_ONLN)"; \
    else \
        mkdir -p /build/nginx/objs \
        && cp /usr/sbin/nginx /build/nginx/objs/nginx; \
    fi

FROM nginx:1.27-alpine
ARG SSL_KEYLOG=true
COPY --from=nginx-build /build/nginx/objs/nginx /usr/sbin/nginx
ENV SSL_KEYLOG_BUILT=${SSL_KEYLOG}
RUN apk add --no-cache openssl ca-certificates

WORKDIR /app
COPY certs/ certs/
COPY domains/ domains/
COPY generate.sh start.sh ./
COPY nginx.conf /etc/nginx/templates/nginx.conf.template
COPY ssl-keylog.conf /etc/nginx/templates/ssl-keylog.conf

RUN chmod +x generate.sh start.sh && mkdir -p generated certs \
    && rm -f /etc/nginx/conf.d/default.conf

EXPOSE 80 443

# start.sh explicitly renders templates before generation and Nginx startup.
ENTRYPOINT ["/app/start.sh"]
CMD []
