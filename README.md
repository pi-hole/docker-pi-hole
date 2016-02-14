A Docker project to make lightweight x86 continers with [pi-hole](https://pi-hole.net) functionality.  

## Docker tags

### Alpine

[![](https://badge.imagelayers.io/diginc/pi-hole:alpine.svg)](https://imagelayers.io/?images=diginc/pi-hole:alpine 'Get your own badge on imagelayers.io')
This is an optimized docker using [alpine](https://hub.docker.com/_/alpine/) as its base.  It uses nginx instead of lighttpd.

### Debian

[![](https://badge.imagelayers.io/diginc/pi-hole:debian.svg)](https://imagelayers.io/?images=diginc/pi-hole:debian 'Get your own badge on imagelayers.io')
This version of the docker aims to be as close to a standard pi-hole installation by using the same base OS and the exact configs and scripts (minimally modified to get them working).  This serves as a nice baseline for merging and testing upstream repository pi-hole changes.

## Basic Docker Usage

The minimum options required to run are:
`docker run -p 53:53/tcp -p 53:53/udp -p 8053:80 --cap-add=NET_ADMIN -d diginc/pi-hole`
dnsmasq requires NET_ADMIN capabilities to run correctly in docker.  I'm arbitrarily choosing port 8053 for the web interface.

**Updating ad sources** - Just run a `docker restart your_pihole_name` to kick off the gravity script which updates all the ad lists.

Here are some useful volume mount options to persist your history of stats in the admin interface, or add custom whitelists/blacklists.  **Create these files on the docker host first or you'll get errors**:

* `docker run -v /var/log/pihole.log:/var/log/pihole.log ...` (plus all of the minimum options added)
* `docker run -v /etc/pihole/blacklist.txt:/etc/pihole/blacklist.txt ...` (plus all of the minimum options added)
* `docker run -v /etc/pihole/whitelist.txt:/etc/pihole/whitelist.txt ...` (plus all of the minimum options added)
 * if you use this you should probably read the Advanced Usage section

All of these options get really long when strung together in one command, which is why I'm not going to show all the full commands variations.  This is where [docker-compose](https://docs.docker.com/compose/install/) yml files come in handy for representing [really long docker commands in a readable file format](https://github.com/diginc/docker-pi-hole/blob/master/doco-example.yml).


## Advanced Usage and Notes

The standard pi-hole customization abilities apply to this docker, but with docker twists such as using docker volume mounts to map host stored file configurations over the container defaults.  Volumes are also important to persist the configuration incase you have remove the pi-hole container which is a typical docker upgrade pattern.

### Customizing with volume mounts

Here are some relevant wiki pages from pi-hole's documentation and example volume mappings to optionally add to the basic example:

* [Customizing sources for ad lists](https://github.com/pi-hole/pi-hole/wiki/Customising-sources-for-ad-lists)
 * `-v your-adlists.list:/etc/pihole/adlists.list` Your version should probably start with the existing defaults for this file.
* [Whitlisting and Blacklisting](https://github.com/pi-hole/pi-hole/wiki/Whitelisting-and-Blacklisting)
 * `-v your-whitelist:/etc/pihole/whitelist.txt` Your version should probably start with the existing defaults for this file.
 * `-v your-blacklist:/etc/pihole/blacklist.txt` This one is empty by default

### Scripts inside the docker

The original pi-hole scripts are in the container, so they should work **for the debian version**, via `docker exec` like so:

* `docker exec pihole_container_name whitelist.sh some-good-domain.com`
* `docker exec pihole_container_name blacklist.sh some-bad-domain.com`

`diginc/pi-hole:debian` has working `service` command functionality, which the original scripts also use to reload after configuration changes. `diginc/pi-hole:alpine` does **not** use `service`, so while the scripts may (or may not) work, to make the changes scripts make take effect please run `docker restart pihole`.
