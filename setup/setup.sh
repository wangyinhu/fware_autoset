#!/bin/bash

VNET="192.168.210.0"
echo "VNET="$VNET

SETUPDIR=$(pwd)
echo "setup dir="$SETUPDIR

ips=$(hostname -I)
ipsa=($ips)
INTERFACE_IP=${ipsa[0]}
echo "listen address="$INTERFACE_IP

OLISTENPORT=28562
read -p "Enter listen port of ocserv service, default=$OLISTENPORT: " PORTREAD

if [[ $PORTREAD =~ ^[0-9]+$ ]] || [[ -z $response ]]; then
	if [[ $PORTREAD =~ ^[0-9]+$ ]]; then
    OLISTENPORT=$PORTREAD
  fi
	echo "listen port="$OLISTENPORT
else
	echo "invalide port number"
	exit 1
fi

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

INTERFACE_NAME="null"

for interface_name in $(ls /sys/class/net)
do
	if [[ $interface_name == ens* ]] || [[ $interface_name == eth* ]] || [[ $interface_name == wlo* ]]; then
		INTERFACE_NAME=$interface_name
		echo "interface name="$INTERFACE_NAME
        break
    fi
done

if [[ $INTERFACE_NAME == "null" ]]; then
	echo "no avalible interface found."
	exit 1
fi

read -r -p "Are you sure? [Y/n]" response
response=${response,,} # tolower
if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
	echo "OK"
else
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must run as root"
   exit 1
fi

echo "installing the ocserv"
apt install nginx ocserv gnutls-bin aria2

echo "goto /etc/ocserv/"

cd /etc/ocserv/ || exit 1

echo "generating file ca.tmpl server.tmpl"

cp $SETUPDIR/ca.tmpl ca.tmpl
cp $SETUPDIR/server.tmpl server.tmpl
sed -i -e "s/INTERFACE_IP/$INTERFACE_IP/g" server.tmpl


certtool --generate-privkey --outfile ca-key.pem
certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
certtool --generate-privkey --outfile server-key.pem
certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem

sed -i -e "s/443/$OLISTENPORT/g" /lib/systemd/system/ocserv.socket

OCSERV_CONF="ocserv.conf"
echo "generating file $OCSERV_CONF"

if [ ! -f $OCSERV_CONF.bkp ]; then
	mv $OCSERV_CONF $OCSERV_CONF.bkp
else
	echo "back up file exists"
fi


cp $SETUPDIR/ocserv.conf $OCSERV_CONF
sed -i -e "s/LISTENPORT/$OLISTENPORT/g" $OCSERV_CONF
sed -i -e "s/VNET/$VNET/g" $OCSERV_CONF

echo "done!"

while true
do
  read -p "please input usrename for ocpasswd, inter empty to quit: " USERNAME
  if [[ -z "$USERNAME" ]]; then
    echo "done"
    break
  fi
  #生成密码
  echo "please input password for auth ocpasswd"
  ocpasswd -c /etc/ocserv/ocpasswd $USERNAME   
done

echo "done!"

echo "************now install the sss!************"

while true
do
  read -p "please input password for sss: " PASSWORD
  if [[ -z "$PASSWORD" ]]; then
    echo "password can not be none!!"
    continue
  fi
  echo "password="$PASSWORD
  break
done

echo "installing software"
apt install shadowsocks-libev

echo "goto /etc/shadowsocks-libev/"

cd /etc/shadowsocks-libev/ || exit 1

echo "changing config parameter..."

sed -i -e "s/8388/$SLISTENPORT/g" config.json
sed -i -e "s/127.0.0.1/$INTERFACE_IP/g" config.json

echo "install sss-libev done!"

echo "************iptables config************"

iptables -t nat -A POSTROUTING -s $VNET/24 -o $INTERFACE_NAME -j MASQUERADE


#stop 443 port access
iptables -I INPUT -p tcp --dport 443 -j DROP

iptables -I INPUT -p tcp --dport $OLISTENPORT -j DROP
iptables -I INPUT -p tcp --dport $SLISTENPORT -j DROP

#access for ssh tunnel
iptables -I INPUT -s localhost -p tcp --dport $OLISTENPORT -j ACCEPT
iptables -I INPUT -s localhost -p tcp --dport $SLISTENPORT -j ACCEPT

while true
do
	read -p "Enter accepted client IP address: " CLIENT_IP

	if [[ $CLIENT_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "adding iptables rule for client ip="$CLIENT_IP
		iptables -I INPUT -s $CLIENT_IP -p tcp --dport $OLISTENPORT -j ACCEPT
		iptables -I INPUT -s $CLIENT_IP -p tcp --dport $SLISTENPORT -j ACCEPT
	else
		break
	fi

done

echo "done!"

while true
do
  read -p "please input linux usrename for ippass script generation: " LUNM
  if [[ -z "$LUNM" ]]; then
    echo "done"
    break
  fi

  echo "generating ippass.sh"
  IPPASS=/home/$LUNM/ippass.sh
  cp $SETUPDIR/ippass.sh $IPPASS
  sed -i -e "s/SLISTENPORT/$SLISTENPORT/g" $IPPASS
  sed -i -e "s/OLISTENPORT/$OLISTENPORT/g" $IPPASS
  chown $LUNM:$LUNM $IPPASS
  chmod +x $IPPASS

  echo "generating root pass script file"
  cp $SETUPDIR/root_pass.sh /home/$LUNM/root_pass.sh
  sed -i -e "s/LUNM/$LUNM/g" /home/$LUNM/root_pass.sh
  sed -i -e "s/28562/$OLISTENPORT/g" /home/$LUNM/root_pass.sh
  sed -i -e "s/38562/$SLISTENPORT/g" /home/$LUNM/root_pass.sh

  echo "generating root flush script file"
  cp $SETUPDIR/root_flush.sh /home/$LUNM/root_flush.sh
  sed -i -e "s/LUNM/$LUNM/g" /home/$LUNM/root_flush.sh
  sed -i -e "s/28562/$OLISTENPORT/g" /home/$LUNM/root_flush.sh
  sed -i -e "s/38562/$SLISTENPORT/g" /home/$LUNM/root_flush.sh
done

echo "done!"

apt install iptables-persistent netfilter-persistent

netfilter-persistent save

cd /var/www/html/ || exit

git clone https://github.com/ziahamza/webui-aria2

# sysctl config
SYSCTL_CONF="/etc/sysctl.conf"
sed -i -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" $SYSCTL_CONF

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

echo "starting service ocserv...."
service ocserv restart
echo "ocserv done!"

echo "starting ss service..."
service shadowsocks-libev restart
echo "all job done!"
