#!/bin/sh
dnsmasq --test || exit 1
php-fpm -t || exit 1
nginx -t || exit 1

gravity.sh # pi-hole version minus the service dnsmasq start
dnsmasq
php-fpm
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
