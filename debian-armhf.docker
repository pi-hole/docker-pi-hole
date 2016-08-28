FROM resin/armv7hf-debian:jessie
MAINTAINER adam@diginc.us <adam@diginc.us>

# Requirements
RUN apt-get -q update && \
    apt-get install -y \
        bash \
        dnsmasq \
        lighttpd \
        php5-common php5-cgi php5 \
        bc curl unzip wget sudo && \
    rm -rf /var/cache/apt/archives

# Original upstream pihole code being used
COPY ./pi-hole/gravity.sh /usr/local/bin/
COPY ./pi-hole/adlists.default /etc/pihole/
COPY ./pi-hole/pihole /usr/local/bin/
COPY ./pi-hole/advanced/Scripts/* /usr/local/bin/
RUN mkdir -p /opt/ && ln -s /usr/local/bin /opt/pihole
COPY ./pi-hole/advanced/lighttpd.conf.debian /etc/lighttpd/lighttpd.conf
COPY ./pi-hole/advanced/dnsmasq.conf.original /etc/dnsmasq.conf
COPY ./pi-hole/advanced/01-pihole.conf /etc/dnsmasq.d/
COPY ./pi-hole/advanced/index.html /var/www/html/pihole/index.html
COPY ./pi-hole/advanced/pihole.sudo /etc/sudoers.d/pihole
COPY ./AdminLTE /var/www/html/admin
COPY ./AdminLTE_version.txt /etc/
COPY ./pi-hole_version.txt /etc/

ENV WEBLOGDIR /var/log/lighttpd
RUN mkdir -p /etc/pihole/ && \
    mkdir -p /var/www/html/pihole && \
    mkdir -p /var/www/html/admin/ && \
    chown www-data:www-data /var/www/html && \
    touch ${WEBLOGDIR}/access.log ${WEBLOGDIR}/error.log && \
    chown -R www-data.www-data ${WEBLOGDIR} && \
    chmod 775 /var/www/html && \
    lighty-enable-mod fastcgi fastcgi-php || true && \
    touch /var/log/pihole.log && \
    chmod 644 /var/log/pihole.log && \
    chown dnsmasq:root /var/log/pihole.log && \
    sed -i "s/@INT@/eth0/" /etc/dnsmasq.d/01-pihole.conf && \
    sed -i 's|"cd /etc/.pihole/ && git describe --tags --abbrev=0"|"cat /etc/pi-hole_version.txt"|g' /var/www/html/admin/footer.php && \
    sed -i 's|"git describe --tags --abbrev=0"|"cat /etc/AdminLTE_version.txt"|g' /var/www/html/admin/footer.php

# This chould be eliminated if all (upstream) files were +x in git
RUN chmod +x /usr/local/bin/*.sh

# Fix dnsmasq in docker
RUN grep -q '^user=root' || echo 'user=root' >> /etc/dnsmasq.conf

# php config start passes special ENVs into
ENV PHP_ENV_CONFIG '/etc/lighttpd/conf-enabled/15-fastcgi-php.conf'
ENV PHP_ERROR_LOG '/var/log/lighttpd/error.log'
COPY ./debian-armhf/start.sh /

EXPOSE 53 53/udp
EXPOSE 80

ENTRYPOINT ["/bash", "-c"]
CMD /start.sh
