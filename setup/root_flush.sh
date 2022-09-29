#!/bin/bash
ipaddress="null"
FLUSH_FILE=/home/LUNM/flush_ip.txt
touch $FLUSH_FILE
chown LUNM:LUNM $FLUSH_FILE
while inotifywait -e close_write $FLUSH_FILE; do
	while read line; do
		ipaddress=$line
		echo $ipaddress
		iptables -D INPUT -s "$ipaddress" -p tcp --dport 38562 -j ACCEPT
  done < $FLUSH_FILE
  : > $FLUSH_FILE
done
netfilter-persistent save
