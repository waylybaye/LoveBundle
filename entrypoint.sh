#!/bin/sh
cat /etc/love/templates/supervisord.conf | mo > /etc/love/supervisord.conf
export HA_SS_TLS_DOMAINS="${SS_TLS_DOMAINS//,/ }"
export HA_SS_HTTP_DOMAINS="${SS_HTTP_DOMAINS//,/ }"
export HA_SSR_HTTP_DOMAINS="${SSR_HTTP_DOMAINS//,/ }"
export HA_SSR_TLS_DOMAINS="${SSR_TLS_DOMAINS//,/ }"
export HA_V2RAY_DOMAINS="${V2RAY_DOMAINS//,/ }" 
cat /etc/love/templates/haproxy.conf | mo > /etc/love/haproxy.conf

exec "$@"
