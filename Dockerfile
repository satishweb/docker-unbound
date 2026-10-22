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
    && test "$(apk list --installed unbound 2>/dev/null | head -1 | awk '{print $1}')" = "unbound-${UNBOUND_VERSION}"

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

# The certificate authority of the internet and the root anchor key are
# prepared while the image is built. The container does not have to download
# them when it starts, it does not need the network and it does not need the
# root rights for it.
#
# The control certificates of the resolver are not prepared here, they are
# secrets and every container needs its own ones. They are created when the
# container starts.
RUN curl -fsSL https://data.iana.org/root-anchors/icannbundle.pem \
        --output /etc/unbound/keys/icannbundle.pem \
    && ln -s /etc/unbound/keys/icannbundle.pem /etc/unbound/icannbundle.pem \
    && ln -s /etc/unbound/keys/icannbundle.pem /icannbundle.pem \
    && unbound-anchor -a /etc/unbound/keys/root.key || true

# The files of the configuration belong to the user the container runs as, the
# container does not have to change the owner of them when it starts.
RUN chown -Rf unbound:unbound /etc/unbound

# The job that updates the block list. The directory of the periodic jobs
# belongs to root, the job is created while the image is built. The settings
# of the block list sources are read from a file that the entrypoint writes
# when the container starts.
RUN printf '#!/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n. /etc/unbound/sources.env\n. /scripts/update_blocked_hosts.sh /etc/unbound/unbound.blocked.hosts\n' > /etc/periodic/daily/updatehosts \
    && chmod 0755 /etc/periodic/daily/updatehosts \
    && chown unbound:unbound /etc/periodic/daily/updatehosts

# The crontab of the user, the cron daemon of busybox reads the file of the
# user it runs as.
RUN cp /etc/crontabs/root /etc/crontabs/unbound \
    && chown unbound:unbound /etc/crontabs/unbound

# The container runs as the user of the resolver, it does not need the root
# rights for anything.
USER unbound

# Run the command on container startup
ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]

# Healthcheck
# The check asks the server for a name, every answer proves that it is
# running. It does not depend on the internet.
HEALTHCHECK --interval=1m --timeout=30s --start-period=30s --retries=3 \
    CMD /docker-healthcheck
