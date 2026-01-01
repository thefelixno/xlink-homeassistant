##### new
FROM alpine:latest

RUN apk add --no-cache wireguard-tools socat bash iproute2

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

ENV LINK_MTU=1380

ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
