#!/bin/sh
gravity.sh # pi-hole version minus the service dnsmasq start

dnsmasq --test || exit 1
dnsmasq

php-fpm -t || exit 1
php-fpm

nginx -t || exit 1
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
