FROM alpine:latest

RUN apk add --no-cache bash curl

COPY src/crontab /var/spool/cron/crontabs/root
COPY src/sync.sh /sync.sh

RUN chmod +x /sync.sh

ENTRYPOINT ["crond", "-f"]
CMD ["-L", "/dev/stdout"]
