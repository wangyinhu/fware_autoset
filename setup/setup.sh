#!/bin/bash

SETUPDIR=$(pwd)
echo "setup dir="$SETUPDIR

SLISTENPORT=38562
read -p "Enter listen port of ss service, default=$SLISTENPORT: " PORTREAD

if [[ $PORTREAD =~ ^[0-9]+$ ]] || [[ -z $response ]]; then
	if [[ $PORTREAD =~ ^[0-9]+$ ]]; then
    SLISTENPORT=$PORTREAD
  fi
	echo "listen port="$SLISTENPORT
else
	echo "invalide port number"
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must run as root"
   exit 1
fi

echo "installing software"
apt install shadowsocks-libev nginx aria2 iptables-persistent netfilter-persistent

read -p "random sss password is in /etc/shadowsocks-libev/config.json[ok]"

echo "goto /etc/shadowsocks-libev/"

cd /etc/shadowsocks-libev/ || exit 1

echo "changing config parameter..."

sed -i -e "s/8388/$SLISTENPORT/g" config.json
sed -i -e "s/127.0.0.1/0.0.0.0/g" config.json
sed -i -e "s/::1/::0/g" config.json

echo "install sss-libev done!"

echo "************iptables config************"

iptables -I INPUT -p tcp --dport $SLISTENPORT -j DROP

#access for ssh tunnel
iptables -I INPUT -s localhost -p tcp --dport $SLISTENPORT -j ACCEPT

netfilter-persistent save

LUNM=$(logname)

echo "generating root pass script file"
cp $SETUPDIR/root_pass.sh /home/$LUNM/root_pass.sh
sed -i -e "s/LUNM/$LUNM/g" /home/$LUNM/root_pass.sh
sed -i -e "s/38562/$SLISTENPORT/g" /home/$LUNM/root_pass.sh

echo "generating root flush script file"
cp $SETUPDIR/root_flush.sh /home/$LUNM/root_flush.sh
sed -i -e "s/LUNM/$LUNM/g" /home/$LUNM/root_flush.sh
sed -i -e "s/38562/$SLISTENPORT/g" /home/$LUNM/root_flush.sh

echo "done!"

cd /var/www/html/ || exit

git clone https://github.com/ziahamza/webui-aria2

# sysctl config
SYSCTL_CONF="/etc/sysctl.conf"

NEEDLE="net.core.default_qdisc = fq"
if grep -Fxq "$NEEDLE" $SYSCTL_CONF
then
echo "$NEEDLE" >> $SYSCTL_CONF
fi

NEEDLE="net.ipv4.tcp_congestion_control = bbr"
if grep -Fxq "$NEEDLE" $SYSCTL_CONF
then
echo "$NEEDLE" >> $SYSCTL_CONF
fi

NEEDLE="net.ipv4.tcp_fastopen = 3"
if grep -Fxq "$NEEDLE" $SYSCTL_CONF
then
echo "$NEEDLE" >> $SYSCTL_CONF
fi

sysctl -p

echo "starting ss service..."
service shadowsocks-libev restart
echo "all job done!"
