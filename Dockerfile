FROM alpine
MAINTAINER HyperApp <hyperappcloud@gmail.com>

#### Build ARGS ####

ARG SS_VER=3.2.3
ARG SS_OBFS_VER=0.0.5
ARG OC_VERSION=0.11.11
# V2Ray is always installed from latest official build

#### VOLUME
ENV TLS_PORT=
ENV DASHBOARD_PORT=
ENV DASHBOARD_PASS hyperapp
ENV CERTS_ROOT /srv/certs
ENV CA_ROOT /srv/ca

RUN mkdir -p /srv/certs && \
    mkdir -p /var/log/love && \
    mkdir -p /etc/love/ && \
    mkdir -p /opt/ && \
    mkdir -p $CA_ROOT

# certs dir
VOLUME /srv/certs/
VOLUME $CA_ROOT
# log dir
VOLUME /var/log/love
# config dir
VOLUME /etc/love


#### CONFIGURATION ####

# Global
ENV LOVE_USERNAME hyperapp
ENV LOVE_PASSWORD hyperapp

ENV LISTEN_ADDRESS 127.0.0.1
ENV SS_TLS_PORT 21025
ENV SSR_TLS_PORT 21027
ENV V2RAY_TLS_PORT 21029
ENV V2RAY_WS_PORT 21030
ENV HTTP2_PORT 21031
ENV HTTP_PROXY_PORT 21032
ENV OCSERV_PORT 21033
ENV OC_LAN_NETWORK 10.10.10.0

# Shadowsocks
ENV ENABLE_SS true
ENV SS_METHOD rc4-md5
ENV SS_TLS_DOMAINS bing.com

# ShadowsocksR
ENV ENABLE_SSR true
ENV SSR_METHOD none
ENV SSR_PROTOCOL auth_chain_b
ENV SSR_TLS_DOMAIN cloudflare.com

# V2ray
ENV ENABLE_V2RAY true
ENV V2RAY_INSECURE true
ENV V2RAY_TLS_DOMAIN=
ENV V2RAY_WS_DOMAIN=

# nghttpx
ENV ENABLE_HTTP2 true
ENV HTTP2_DOMAIN=

# OCSERV
ENV ENABLE_OCSERV true
ENV OCSERV_INSECURE false
ENV OCSERV_DOMAIN=


ADD etc /etc/love/templates

######## INSTALLATION #########
RUN apk add --no-cache curl bash && \
    curl -sSO https://raw.githubusercontent.com/tests-always-included/mo/master/mo && \
    mv mo /usr/local/bin && \
    chmod +x /usr/local/bin/mo

#### Install supervisord ####
RUN apk add --no-cache python py-pip && pip install supervisor supervisor-stdout



#### Install Shadowsocks ####
RUN set -ex && \
    apk add --no-cache udns && \
    apk add --no-cache --virtual .build-deps \
                                git \
                                autoconf \
                                automake \
                                make \
                                build-base \
                                curl \
                                libev-dev \
                                c-ares-dev \
                                libtool \
                                linux-headers \
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


#### Install SSR
ADD shadowsocksr-manyuser.zip /tmp
RUN unzip /tmp/shadowsocksr-manyuser.zip -d /tmp/ \
    && mv /tmp/shadowsocksr-manyuser /opt/ \
    && rm /tmp/shadowsocksr-manyuser.zip

#### Install V2ray
COPY --from=v2ray/official:latest  /usr/bin/v2ray/v2ray /usr/local/bin/
COPY --from=v2ray/official:latest  /usr/bin/v2ray/v2ctl /usr/local/bin/
COPY --from=v2ray/official:latest  /usr/bin/v2ray/geoip.dat /usr/local/bin/
COPY --from=v2ray/official:latest  /usr/bin/v2ray/geosite.dat /usr/local/bin/

#### Install nghttpx

RUN apk add --no-cache nghttp2 openssl ca-certificates apache2-utils
#CMD nghttpx --http2-proxy -f $FRONTEND -b $BACKEEND $OPTIONS /certs/${DOMAIN}.key /certs/${DOMAIN}.crt


#### Install ocserv
RUN apk add --update --no-cache musl-dev iptables libev openssl gnutls-dev readline-dev libnl3-dev lz4-dev libseccomp-dev gnutls-utils

RUN buildDeps="xz gcc autoconf make linux-headers libev-dev  "; \
	set -x \
	&& apk add --no-cache $buildDeps \
	&& mkdir /src && cd /src \
	&& OC_FILE="ocserv-$OC_VERSION" \
	&& rm -fr download.html \
	&& wget ftp://ftp.infradead.org/pub/ocserv/$OC_FILE.tar.xz \
	&& tar xJf $OC_FILE.tar.xz \
	&& rm -fr $OC_FILE.tar.xz \
	&& cd $OC_FILE \
	&& sed -i '/#define DEFAULT_CONFIG_ENTRIES /{s/96/200/}' src/vpn.h \
	&& ./configure \
	&& make -j"$(nproc)" \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cp ./doc/sample.config /etc/ocserv/ocserv.conf \
	&& cd \
	&& rm -fr ./$OC_FILE \
	&& apk del --purge $buildDeps \
        && rm -rf /src

### Install haproxy
RUN apk add --no-cache haproxy

ADD entrypoint.sh /usr/local/bin
ADD gencert.sh /usr/local/bin
ENTRYPOINT ["entrypoint.sh"]
