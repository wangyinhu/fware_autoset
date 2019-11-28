#!/bin/bash
ipaddress="null"
PASS_FILE=/home/LUNM/flush_ip.txt
while inotifywait -e close_write $PASS_FILE; do
	temp="$(cat $PASS_FILE)"
	if [ "$temp" != "$ipaddress" ]; then
		ipaddress=$temp
		echo $ipaddress
		iptables -I INPUT -s "$ipaddress" -p tcp --dport 28562 -j ACCEPT
		iptables -I INPUT -s "$ipaddress" -p tcp --dport 38562 -j ACCEPT
	fi
done
netfilter-persistent save
