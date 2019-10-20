#!/bin/bash

VNET="192.168.210.0"
echo "VNET="$VNET

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

ips=$(hostname -I)
ipsa=($ips)
INTERFACE_IP=${ipsa[0]}
echo "listen address="$INTERFACE_IP

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
   echo "This script must be run as root"
   exit 1
fi

echo "installing the ocserv"
apt install ocserv gnutls-bin

echo "goto /etc/ocserv/"

cd /etc/ocserv/ || exit 1

echo "generating file 'ca.tmpl'"

echo "cn = \"VPN CA\"
organization = \"heheda\"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key " > ca.tmpl

echo "done!"

echo "generating file 'server.tmpl'"

echo "cn = $INTERFACE_IP
organization = \"heheda\"
expiration_days = 3650
signing_key
encryption_key
tls_www_server" > server.tmpl

echo "done!"


certtool --generate-privkey --outfile ca-key.pem
certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
certtool --generate-privkey --outfile server-key.pem
certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem

sed -i -e "s/443/$OLISTENPORT/g" /lib/systemd/system/ocserv.socket

sed -i -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf

sysctl -p /etc/sysctl.conf


echo "generating file 'ocserv.conf'"

if [ ! -f ocserv.conf.bkp ]; then
	mv ocserv.conf ocserv.conf.bkp
else
	echo "back up file exists"
fi


echo "auth = \"plain[/etc/ocserv/ocpasswd]\"
tcp-port = $OLISTENPORT
udp-port = $OLISTENPORT
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = /etc/ocserv/server-cert.pem
server-key = /etc/ocserv/server-key.pem
ca-cert = /etc/ssl/certs/ssl-cert-snakeoil.pem
isolate-workers = true
max-clients = 16
max-same-clients = 20
keepalive = 32400
dpd = 10
mobile-dpd = 1800
try-mtu-discovery = true
cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = \"NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0\"
auth-timeout = 240
min-reauth-time = 3
max-ban-score = 50
ban-reset-time = 300
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-utmp = true
use-occtl = true
pid-file = /var/run/ocserv.pid
device = vpns
predictable-ips = true
default-domain = example.com
ipv4-network = $VNET
ipv4-netmask = 255.255.255.0
tunnel-all-dns = true
dns = 8.8.8.8
ping-leases = false
cisco-client-compat = true
dtls-legacy = true
" > ocserv.conf

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
apt install shadowsocks

echo "goto /etc/shadowsocks/"

cd /etc/shadowsocks/ || exit 1

echo "changing config parameter..."

sed -i -e "s/my_server_ip/$INTERFACE_IP/g" config.json
sed -i -e "s/8388/$SLISTENPORT/g" config.json
sed -i -e "s/mypassword/$PASSWORD/g" config.json

echo "install sss done!"

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

echo "generating ippass.sh ..."

while true
do
  read -p "please input linux usrename for ippass script generation: " LUNM
  if [[ -z "$LUNM" ]]; then
    echo "done"
    break
  fi
  echo "iptables -I INPUT -s \"\$1\" -p tcp --dport $SLISTENPORT -j ACCEPT" >> /home/$LUNM/ippass.sh
  echo "iptables -I INPUT -s \"\$1\" -p tcp --dport $OLISTENPORT -j ACCEPT" >> /home/$LUNM/ippass.sh
  chown $LUNM:$LUNM /home/$LUNM/ippass.sh
  chmod +x /home/$LUNM/ippass.sh

  echo "generating root pass script file"
  echo "#!/bin/bash
  ipaddress=\"null\"
  while inotifywait -e close_write /home/$LUNM/pass_ip.txt; do
    temp=\"\$(cat /home/$LUNM/pass_ip.txt)\"
    if [ \"\$temp\" != \"\$ipaddress\" ]; then
      ipaddress=\$temp
      echo \$temp
      iptables -I INPUT -s \"\$ipaddress\" -p tcp --dport $SLISTENPORT -j ACCEPT
      iptables -I INPUT -s \"\$ipaddress\" -p tcp --dport $OLISTENPORT -j ACCEPT
    fi
  done
  " > /home/$LUNM/root_pass.sh
done

echo "done!"

apt install iptables-persistent netfilter-persistent

netfilter-persistent save


echo "starting service ocserv...."
service ocserv restart
echo "ocserv done!"

echo "starting ss service..."
service shadowsocks restart
echo "all job done!"
