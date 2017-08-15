#!/bin/sh
set -e

CERTS_DIR=$CA_ROOT
mkdir -p $CERTS_DIR
cd $CERTS_DIR
DOMAIN="$1"

if [ ! -z "$2" ] && [ ! -z "$3" ]; then
  USERNAME="$2"
  PASSWORD="$3"
  CLIENT="${USERNAME}@${DOMAIN}"
fi

cat > hyperapp-ca.tmpl <<_EOF_
cn = "HyperApp Root CA"
organization = "HyperApp"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key
_EOF_

cat > hyperapp-server.tmpl <<_EOF_
cn = "${DOMAIN}"
dns_name = "${DOMAIN}"
organization = "HyperApp"
serial = 2
expiration_days = 3650
encryption_key
signing_key
tls_www_server
_EOF_

cat > hyperapp-client.tmpl <<_EOF_
cn = "client@${DOMAIN}"
uid = "client@${DOMAIN}"
unit = "HyperApp"
expiration_days = 3650
signing_key
tls_www_client
_EOF_


if [ ! -f "${CERTS_DIR}/hyperapp-ca-key.pem" ]; then
  echo "[INFO] generating root CA"
  # gen ca keys
  certtool --generate-privkey \
           --outfile hyperapp-ca-key.pem

  certtool --generate-self-signed \
           --load-privkey /etc/ocserv/certs/hyperapp-ca-key.pem \
           --template hyperapp-ca.tmpl \
           --outfile hyperapp-ca-cert.pem
fi


if [ ! -f "${CERTS_DIR}/${DOMAIN}".self-signed.crt ]; then
  echo "[INFO] generating ${DOMAIN} certs"
  certtool --generate-privkey \
           --outfile "${DOMAIN}".self-signed.key

  certtool --generate-certificate \
           --load-privkey "${DOMAIN}".self-signed.key \
           --load-ca-certificate hyperapp-ca-cert.pem \
           --load-ca-privkey hyperapp-ca-key.pem \
           --template hyperapp-server.tmpl \
           --outfile "${DOMAIN}".self-signed.crt
fi


if [ ! -f "${CERTS_DIR}/${CLIENT}".p12 ]; then
  echo "[INFO] generating client certs"

  # gen client keys
  certtool --generate-privkey \
           --outfile "${CLIENT}"-key.pem

  certtool --generate-certificate \
           --load-privkey "${CLIENT}"-key.pem \
           --load-ca-certificate hyperapp-ca-cert.pem \
           --load-ca-privkey hyperapp-ca-key.pem \
           --template hyperapp-client.tmpl \
           --outfile "${CLIENT}"-cert.pem

  certtool --to-p12 \
           --pkcs-cipher 3des-pkcs12 \
           --load-ca-certificate hyperapp-ca-cert.pem \
           --load-certificate "${CLIENT}"-cert.pem \
           --load-privkey "${CLIENT}"-key.pem \
           --outfile "${CLIENT}".p12 \
           --outder \
           --p12-name "${DOMAIN}" \
           --password "${PASSWORD}"
fi

rm hyperapp-ca.tmpl
rm hyperapp-server.tmpl
rm hyperapp-client.tmpl
