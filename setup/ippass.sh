iptables -I INPUT -s "$1" -p tcp --dport SLISTENPORT -j ACCEPT
