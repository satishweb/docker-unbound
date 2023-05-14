# Author: Satish Gaikwad <satish@satishweb.com>
FROM alpine:latest
LABEL MAINTAINER satish@satishweb.com

RUN apk add \
        supervisor \
        drill \
        gettext \
        bind-tools \
        sudo \
        openssl \
        curl

ARG UNBOUND_VERSION 1.17.1-r1

RUN apk add \
        unbound=${UNBOUND_VERSION} \
    && rm -rf /etc/unbound/unbound.conf /etc/unbound/root.hints

# Add supervisord.conf
ADD supervisor-unbound.ini /etc/supervisor.d/supervisor-unbound.ini

# Add scripts and make them executable
ADD unbound.sample.conf /templates/unbound.sample.conf
ADD docker-entrypoint /docker-entrypoint
COPY scripts /scripts
RUN chmod u+x /docker-entrypoint /scripts/*
RUN mkdir -p /etc/unbound/keys /etc/unbound/custom

# Setup rootkeys
# Forcing ipv4 as docker builder is not setup with ipv6
RUN curl  --ipv4 https://www.internic.net/domain/named.root > /etc/unbound/root.hints

# Run the command on container startup
ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]

# Healthcheck
HEALTHCHECK --interval=1m --timeout=30s --start-period=10s CMD drill @127.0.0.1 google.com || exit 1
