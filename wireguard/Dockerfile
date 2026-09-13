ARG BUILD_FROM
FROM $BUILD_FROM

RUN apt update && apt install -y wireguard-tools iproute2

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
