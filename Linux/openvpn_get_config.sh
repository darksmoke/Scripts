#/usr/bin/env bash
NAME=$1
OVPN_HOME=/etc/openvpn
SERVER_IP="1.1.1.1"

if [ -z $NAME ]; then
    echo "Enter config name! (example: $0 director)"
    exit 1
fi

if [ ! -f ${OVPN_HOME}/easy-rsa/2.0/keys/$1.crt ]; then
    echo "OVPN certificate (CRT) not found!"
    exit 1
fi

if [ ! -f ${OVPN_HOME}/easy-rsa/2.0/keys/$1.key ]; then
    echo "OVPN certificate (KEY) not found!"
    exit 1
fi

mkdir -p ${OVPN_HOME}/client_config
echo "client
dev tun
proto tcp
remote $SEVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
comp-lzo
verb 3" > ${OVPN_HOME}/client_config/$1.ovpn

echo "<ca>" >> ${OVPN_HOME}/client_config/$1.ovpn
cat /etc/openvpn/ca.crt >> ${OVPN_HOME}/client_config/$1.ovpn
echo "</ca>" >> ${OVPN_HOME}/client_config/$1.ovpn

echo "<cert>" >> ${OVPN_HOME}/client_config/$1.ovpn
cat ${OVPN_HOME}/easy-rsa/2.0/keys/$1.crt >> ${OVPN_HOME}/client_config/$1.ovpn
echo "</cert>" >> ${OVPN_HOME}/client_config/$1.ovpn

echo "<key>" >> ${OVPN_HOME}/client_config/$1.ovpn
cat ${OVPN_HOME}/easy-rsa/2.0/keys/$1.key >> ${OVPN_HOME}/client_config/$1.ovpn
echo "</key>" >> ${OVPN_HOME}/client_config/$1.ovpn
