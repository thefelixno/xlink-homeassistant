##### new
ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache wireguard-tools socat bash iproute2

COPY run.sh /
RUN chmod a+x /run.sh

ENV LINK_MTU=1380

CMD [ "/run.sh" ]
