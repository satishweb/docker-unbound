# Author: Satish Gaikwad <satish@satishweb.com>
FROM alpine:latest
LABEL MAINTAINER satish@satishweb.com

RUN apk add \
        bash \
        supervisor \
        unbound \
        drill \
        gettext \
        bind-tools \
        sudo \
        openssl \
    && rm -rf /etc/unbound/unbound.conf

# Add supervisord.conf
ADD supervisor-unbound.ini /etc/supervisor.d/supervisor-unbound.ini

# Add scripts and make them executable
ADD unbound.sample.conf /templates/unbound.sample.conf
ADD docker-entrypoint /docker-entrypoint
COPY scripts /scripts
RUN chmod u+x /docker-entrypoint /scripts/*

# Run the command on container startup
ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]

# Healthcheck
HEALTHCHECK --interval=1m --timeout=30s --start-period=10s CMD drill @127.0.0.1 google.com || exit 1
