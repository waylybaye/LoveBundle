FROM alpine:edge
MAINTAINER HyperApp <hyperappcloud@gmail.com>

#### Build ARGS ####

ARG SS_VER=3.0.8
ARG SS_OBFS_VER=0.0.3
ARG V2RAY_VER=

#### VOLUME
ENV HTTP_PORT=
ENV TLS_PORT=

RUN mkdir -p /srv/certs && \
    mkdir -p /var/log/love && \
    mkdir -p /etc/love/

# certs dir
VOLUME /srv/certs/
# log dir
VOLUME /var/log/love
# config dir
VOLUME /etc/love


#### CONFIGURATION ####

# Global
ENV LOVE_USERNAME hyperapp
ENV LOVE_PASSWORD hyperapp

ENV LISTEN_ADDRESS 127.0.0.1
ENV SS_HTTP_PORT 21024
ENV SS_TLS_PORT 21025
ENV SSR_HTTP_PORT 21026
ENV SSR_TLS_PORT 21027
ENV V2RAY_PORT 21028
ENV HTTP2_PORT 21029
ENV OCSERV_PORT 21030

# Shadowsocks
ENV ENABLE_SS true
ENV SS_METHOD rc4-md5
ENV SS_HOSTS bing.com

# ShadowsocksR
ENV ENABLE_SSR true
ENV SSR_METHOD rc4-md5
ENV SSR_HOSTS cloudflare.com

# V2ray
ENV ENABLE_V2RAY true
ENV V2RAY_INSECURE false
ENV V2RAY_HOSTS yahoo.com

# nghttpx
ENV ENABLE_HTTP2 true
ENV HTTP2_INSECURE false
ENV HTTP2_HOSTS=

# OCSERV
ENV ENABLE_OCSERV true
ENV OCSERV_INSECURE false
ENV OCSERV_HOSTS


ADD etc /etc/love/templates

######## INSTALLATION #########
RUN apk add --no-cache --virtual && \
    curl -sSO https://raw.githubusercontent.com/tests-always-included/mo/master/mo && \
    mv mo /usr/local/bin && \
    chmod +x /usr/local/bin/mo

#### Install supervisord ####
RUN apk add --no-cache python py-pip && pip install supervisor

#### Install Shadowsocks ####
RUN set -ex && \
    apk add --no-cache --virtual .build-deps \
                                git \
                                autoconf \
                                automake \
                                make \
                                build-base \
                                curl \
                                libev-dev \
                                libtool \
                                linux-headers \
                                udns-dev \
                                libsodium-dev \
                                mbedtls-dev \
                                pcre-dev \
                                tar \
                                udns-dev && \

    cd /tmp/ && \
    git clone https://github.com/shadowsocks/shadowsocks-libev.git && \
    cd shadowsocks-libev && \
    git checkout v$SS_VER && \
    git submodule update --init --recursive && \
    ./autogen.sh && \
    ./configure --prefix=/usr --disable-documentation && \
    make install && \
    cd /tmp/ && \
    git clone https://github.com/shadowsocks/simple-obfs.git shadowsocks-obfs && \
    cd shadowsocks-obfs && \
    git checkout v$SS_OBFS_VER && \
    git submodule update --init --recursive && \
    ./autogen.sh && \
    ./configure --prefix=/usr --disable-documentation && \
    make install && \
    cd .. && \

    runDeps="$( \
        scanelf --needed --nobanner /usr/bin/ss-* \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | xargs -r apk info --installed \
            | sort -u \
    )" && \
    apk add --no-cache --virtual .run-deps $runDeps && \
    apk del .build-deps && \
    rm -rf /tmp/*


##### Install nghttpx

RUN apk add --no-cache nghttp2 openssl ca-certificates
ENV FRONTEND=*,443
ENV BACKEEND=backend,8080
ENV DOMAIN=example.com
ENV OPTIONS=""

EXPOSE 443
VOLUME /certs/

#CMD nghttpx --http2-proxy -f $FRONTEND -b $BACKEEND $OPTIONS /certs/${DOMAIN}.key /certs/${DOMAIN}.crt


### Install haproxy
RUN apk add --no-cache haproxy

ADD entrypoint.sh /usr/local/bin
ENTRYPOINT ["entrypoint.sh"]
CMD ["supervisord", "--nodaemon", "--configuration", "/etc/love/supervisord.conf"]
