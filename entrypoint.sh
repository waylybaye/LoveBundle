#!/bin/sh

if [ ! -z "$HTTP2_DOMAIN" ]; then
  if [ -f "/srv/certs/${HTTP2_DOMAIN}.crt" ]; then
    export NGHTTPX_CERT="/srv/certs/${HTTP2_DOMAIN}.crt"
    export NGHTTPX_KEY="/srv/certs/${HTTP2_DOMAIN}.key"
  else
    echo "Generating ${HTTP2_DOMAIN} self-signed cert ..."
    gencert.sh $HTTP2_DOMAIN
    export NGHTTPX_CERT="${CA_ROOT}/${HTTP2_DOMAIN}.self-signed.crt"
    export NGHTTPX_KEY="--insecure ${CA_ROOT}/${HTTP2_DOMAIN}.self-signed.key"
  fi
fi

export HA_SS_TLS_DOMAINS="${SS_TLS_DOMAINS//,/ }"
export HA_SS_HTTP_DOMAINS="${SS_HTTP_DOMAINS//,/ }"
export HA_SSR_HTTP_DOMAINS="${SSR_HTTP_DOMAINS//,/ }"
export HA_SSR_TLS_DOMAINS="${SSR_TLS_DOMAINS//,/ }"

cat /etc/love/templates/haproxy.conf | mo > /etc/love/haproxy.conf

if [ ! -z "$V2RAY_TLS_DOMAIN" ]; then
  if [ -f "/srv/certs/${V2RAY_TLS_DOMAIN}.crt" ]; then
    export V2RAY_TLS_CERT_FILE="/srv/certs/${V2RAY_TLS_DOMAIN}.crt"
    export V2RAY_TLS_KEY_FILE="/srv/certs/${V2RAY_TLS_DOMAIN}.key"
  else
    echo "Generating ${V2RAY_TLS_DOMAIN} self-signed cert ..."
    gencert.sh $V2RAY_TLS_DOMAIN
    export V2RAY_TLS_CERT_FILE="${CA_ROOT}/${V2RAY_TLS_DOMAIN}.self-signed.crt"
    export V2RAY_TLS_KEY_FILE="${CA_ROOT}/${V2RAY_TLS_DOMAIN}.self-signed.key"
  fi
fi

if [ ! -z "$V2RAY_WS_DOMAIN" ]; then
  if [ -f "/srv/certs/${V2RAY_WS_DOMAIN}.crt" ]; then
    export V2RAY_WS_CERT_FILE="/srv/certs/${V2RAY_WS_DOMAIN}.crt"
    export V2RAY_WS_KEY_FILE="/srv/certs/${V2RAY_WS_DOMAIN}.key"
  else
    echo "Generating ${V2RAY_WS_DOMAIN} self-signed cert ..."
    gencert.sh $V2RAY_WS_DOMAIN
    export V2RAY_WS_CERT_FILE="${CA_ROOT}/${V2RAY_WS_DOMAIN}.self-signed.crt"
    export V2RAY_WS_KEY_FILE="${CA_ROOT}/${V2RAY_WS_DOMAIN}.self-signed.key"
  fi
fi


if [ ! -z "$OCSERV_DOMAIN" ] then;
  gencert.sh $OCSERV_DOMAIN $LOVE_USERNAME $LOVE_PASSWORD
  export OCSERV_CA_CERT="$CA_ROOT/hyperapp-ca-key.pem"

  if [ -f "/srv/certs/${OCSERV_DOMAIN}.crt" ]; then
    export OCSERV_CERT="/srv/certs/${OCSERV_DOMAIN}.crt"
    export OCSERV_KEY="/srv/certs/${OCSERV_DOMAIN}.key"
  else
    export OCSERV_CERT="${CA_ROOT}/${OCSERV_DOMAIN}.self-signed.crt"
    export OCSERV_KEY="${CA_ROOT}/${OCSERV_DOMAIN}.self-signed.key"
  fi
fi

cat /etc/love/templates/v2ray_tls.json | mo > /etc/love/v2ray_tls.json
cat /etc/love/templates/v2ray_ws.json | mo > /etc/love/v2ray_ws.json
cat /etc/love/templates/squid.conf | mo > /etc/love/squid.conf
cat /etc/love/templates/ocserv.conf | mo > /etc/love/ocserv.conf

if [ ! -z "$OCSERV_DOMAIN" ]; then
  echo "create ocserv accounts ..."
  echo "${LOVE_PASSWORD}" | ocpasswd -c /etc/love/ocpasswd "${LOVE_USERNAME}"

  if [ ! -e /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
  fi

  iptables -t nat -A POSTROUTING -s ${OC_LAN_NETWORK}/24 -j MASQUERADE
  iptables -A FORWARD -s ${OC_LAN_NETWORK}/24 -j ACCEPT
fi


if [ ! -z "$HTTP2_DOMAIN" ]; then
  htpasswd -bc /etc/love/passwd "${LOVE_USERNAME}" "${LOVE_PASSWORD}"
  CHOWN=$(/usr/bin/which chown)
  SQUID=$(/usr/bin/which squid)
  "$CHOWN" -R squid:squid /var/cache/squid
  "$CHOWN" -R squid:squid /var/log/squid

  if [ ! -f  /var/spool/squid ]; then
    echo "initializing spool ..."
    mkdir /var/spool/squid
  fi

  if [ ! -f  /var/cache/squid ]; then
    echo "initializing cache ..."
    squid -f /etc/love/squid.conf -zN
  fi
fi

cat /etc/love/templates/supervisord.conf | mo > /etc/love/supervisord.conf
exec supervisord --nodaemon --configuration /etc/love/supervisord.conf "$@"
