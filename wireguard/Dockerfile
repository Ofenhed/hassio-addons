ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/home-assistant/${BUILD_ARCH}-base-ubuntu:latest
FROM $BUILD_FROM

RUN apt update && apt install -y wireguard-tools iproute2

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
