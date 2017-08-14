#!/bin/sh
cat /etc/love/templates/supervisord.conf | mo > /etc/love/supervisord.conf
cat /etc/love/templates/haproxy.conf | mo > /etc/love/haproxy.conf

exec "$@"
