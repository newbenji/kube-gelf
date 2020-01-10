FROM debian:buster-slim
LABEL maintainer "Joakim Karlsson <joakim@roffe.nu"
LABEL Description="Fluentd docker image" Vendor="roffe.nu" Version="1.2"

ARG DEBIAN_FRONTEND=noninteractive

ENV DUMB_INIT_SETSID 0
ENV DUMB_INIT_VERSION=1.2.2
ENV JE_MALLOC_VERSION=5.2.1

ENV FLUENTD_CONF="fluent.conf"
ENV FLUENTD_OPT=""

RUN mkdir -p /fluentd/etc /fluentd/plugins /fluentd/log

RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
            ca-certificates \
            ruby \
            procps \
 && buildDeps=" \
      make gcc g++ libc-dev \
      ruby-dev \
      wget bzip2 gnupg dirmngr \
    " \
 && apt-get install -y --no-install-recommends $buildDeps \
 && update-ca-certificates \
 && echo 'gem: --no-document' >> /etc/gemrc \
    fluent-plugin-gelf-hs:1.0.8 \
    fluent-plugin-kubernetes_metadata_filter:1.0.0 \
    fluent-plugin-kubernetes_metadata_filter:2.4.1 \
    fluent-plugin-systemd:1.0.2 \
    fluentd:1.8.1 \
    gelf:3.1.0 \
    json:2.3.0 \
    oj:3.10.0 \
    fluent-plugin-record-modifier:2.1.0

RUN dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_$dpkgArch \
 && chmod +x /usr/bin/dumb-init \
 && wget -O /tmp/jemalloc-JE_MALLOC_VERSION.tar.bz2 https://github.com/jemalloc/jemalloc/releases/download/JE_MALLOC_VERSION/jemalloc-5.2.1.tar.bz2 \
 && cd /tmp && tar -xjf jemalloc-JE_MALLOC_VERSION.tar.bz2 && cd jemalloc-JE_MALLOC_VERSION/ \
 && ./configure && make \
 && mv lib/libjemalloc.so.2 /usr/lib \
 && apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"

# EXPOSE 24224 5140

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD fluentd -c /fluentd/etc/${FLUENTD_CONF} -p /fluentd/plugins $FLUENTD_OPT
