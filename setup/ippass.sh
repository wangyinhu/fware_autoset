iptables -I INPUT -s "$1" -p tcp --dport SLISTENPORT -j ACCEPT
iptables -I INPUT -s "$1" -p tcp --dport OLISTENPORT -j ACCEPT
