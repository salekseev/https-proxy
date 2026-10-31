FROM nginx:1.27-alpine

RUN apk add --no-cache openssl ca-certificates

WORKDIR /app
COPY certs/ certs/
COPY domains/ domains/
COPY generate.sh start.sh ./
COPY nginx.conf /etc/nginx/templates/nginx.conf.template

RUN chmod +x generate.sh start.sh && mkdir -p generated certs \
    && rm -f /etc/nginx/conf.d/default.conf

EXPOSE 80 443

# start.sh explicitly renders templates before generation and Nginx startup.
ENTRYPOINT ["/app/start.sh"]
CMD []
