#!/bin/bash
ipaddress="null"
while inotifywait -e close_write /home/LINUX_USERNAME/1234.txt; do
	temp="$(cat /home/LINUX_USERNAME/1234.txt)"
	if [ "$temp" != "$ipaddress" ]; then
		ipaddress=$temp
		echo $temp
		iptables -I INPUT -s "$ipaddress" -p tcp --dport 28562 -j ACCEPT
		iptables -I INPUT -s "$ipaddress" -p tcp --dport 38562 -j ACCEPT
	fi
done
