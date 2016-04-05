#!/bin/sh

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -P INPUT DROP
#iptables -I INPUT -s x.x.x.x -j ACCEPT


