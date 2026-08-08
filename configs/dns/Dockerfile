# Tiny dnsmasq image: resolves *.test -> 127.0.0.1, forwards everything else.
# Built on the DHI alpine-base (dev flavor → ships a shell + apk). dnsmasq lives
# in upstream Alpine main, which the DHI alpine repo doesn't carry, so add it.
# The entrypoint runs TWO dnsmasq instances: the host-facing one (eth0) baked
# here, plus an in-network view on 172.28.0.53 (lds-dnsnet) that answers *.test
# with the proxy container IP — so browser tools inside the stack (OWASP ZAP)
# can reach local *.test apps. See entrypoint.sh.
ARG DHI_REGISTRY=dhi.io
ARG ALPINE_VERSION=3.24
FROM ${DHI_REGISTRY}/alpine-base:${ALPINE_VERSION}-dev

# DHI defaults to a non-root user; apk (and binding :53 at runtime) need root.
USER root

ARG ALPINE_VERSION=3.24
RUN printf '\nhttps://dl-cdn.alpinelinux.org/alpine/v%s/main\n' "$ALPINE_VERSION" >> /etc/apk/repositories \
    && apk add --no-cache dnsmasq
COPY dnsmasq.conf /etc/dnsmasq.conf
COPY entrypoint.sh /entrypoint.sh
EXPOSE 53/udp 53/tcp
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
