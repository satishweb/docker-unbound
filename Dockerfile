# Author: Satish Gaikwad <satish@satishweb.com>
FROM alpine:3.24
LABEL MAINTAINER=satish@satishweb.com \
      org.opencontainers.image.title="Unbound DNS Cache Server" \
      org.opencontainers.image.description="Unbound DNS cache server with ad blocking" \
      org.opencontainers.image.source="https://github.com/satishweb/docker-unbound" \
      org.opencontainers.image.licenses="MIT"

# The version of the unbound package that is installed. It has to match the
# version of the alpine release, the build fails when it does not.
ARG UNBOUND_VERSION=1.25.2-r2

RUN apk add \
        supervisor \
        drill \
        gettext \
        bind-tools \
        openssl \
        curl

RUN apk add \
        unbound=${UNBOUND_VERSION} \
    && rm -rf /etc/unbound/unbound.conf /etc/unbound/root.hints \
    && test "$(apk info -v unbound)" = "unbound-${UNBOUND_VERSION}"

# Add supervisord.conf
ADD supervisor-unbound.ini /etc/supervisor.d/supervisor-unbound.ini

# Add scripts and make them executable
ADD unbound.sample.conf /templates/unbound.sample.conf
ADD docker-entrypoint /docker-entrypoint
ADD docker-healthcheck /docker-healthcheck
COPY scripts /scripts
RUN chmod u+x /docker-entrypoint /docker-healthcheck /scripts/* \
    && mkdir -p /etc/unbound/keys /etc/unbound/custom

# Setup rootkeys
# Forcing ipv4 as docker builder is not setup with ipv6
RUN curl  --ipv4 https://www.internic.net/domain/named.root > /etc/unbound/root.hints

# The resolver drops the privileges itself, it runs as the unbound user. The
# supervisor needs the root rights to prepare the configuration and the cron
# job.
RUN chown -Rf unbound:unbound /etc/unbound

# Run the command on container startup
ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]

# Healthcheck
# The check asks the server for a name, every answer proves that it is
# running. It does not depend on the internet.
HEALTHCHECK --interval=1m --timeout=30s --start-period=30s --retries=3 \
    CMD /docker-healthcheck
