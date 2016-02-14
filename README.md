A Docker project to make lightweight continers with [https://pi-hole.net](pi-hole) functionality.  

## Docker tags

### Alpine

[![](https://badge.imagelayers.io/diginc/pi-hole:alpine.svg)](https://imagelayers.io/?images=diginc/pi-hole:alpine 'Get your own badge on imagelayers.io')
This is an optimized docker using [https://hub.docker.com/_/alpine/](alpine) as it's base

### Debian

[![](https://badge.imagelayers.io/diginc/pi-hole:debian.svg)](https://imagelayers.io/?images=diginc/pi-hole:debian 'Get your own badge on imagelayers.io')
This version of the docker aims to be as close to a standard pi-hole installation by using the same base OS and the exact configs and scripts (minimally modified to get them working)

## Basic Docker Usage

The minimum options required to run are:
`docker run -p 53:53/tcp -p 53:53/udp -p 8053:80 --cap-add=NET_ADMIN -d diginc/pi-hole`
dnsmasq requires NET_ADMIN capabilities to run correctly in docker.  I'm arbitrarily choosing port 8053 for the web interface.

Here are some useful volume mounts options to persist your history of stats in the admin interface, or add custom whitelists/blacklists.  **Create these files on the docker host first or you'll get errors**:

* `docker run -v /var/log/pihole.log:/var/log/pihole.log ...` (plus all of the minimum options added)
* `docker run -v /etc/pihole/blacklist.txt:/etc/pihole/blacklist.txt ...` (plus all of the minimum options added)
* `docker run -v /etc/pihole/whitelist.txt:/etc/pihole/whitelist.txt ...` (plus all of the minimum options added)
 * if you use this you should probably read the Advanced Usage section

All of these options get really long when strung together in one command, which is why I'm not going to show all the full commands variations.  This is where [https://docs.docker.com/compose/install/](docker-compose) yml files come in handy for representing [https://github.com/diginc/docker-pi-hole/blob/master/doco-example.yml](really long docker commands in a readable file format).

## Advanced Usage

The standard pi-hole customization abilities apply to this docker but with docker twists such as using docker volumes to map host stored file configurations over the container defaults.  Volumes are also important to persist the configuration incase you have remove the pihole container which is a typical docker upgrade pattern.

### Customizing with volume mounts

Here are some relevant wiki page from pi-hole's documentation and example volume mappings to add to your `docker run` command:

* [https://github.com/pi-hole/pi-hole/wiki/Customising-sources-for-ad-lists](Customizing sources for ad lists)
 * `-v your-adlists.list:/etc/pihole/adlists.list` Your version should probably start with the existing defaults for this file.
* [https://github.com/pi-hole/pi-hole/wiki/Whitelisting-and-Blacklisting](Whitlisting and Blacklisting)
 * `-v your-whitelist:/etc/pihole/whitelist.txt` Your version should probably start with the existing defaults for this file.
 * `-v your-blacklist:/etc/pihole/blacklist.txt` This one is empty by default

Since the original scripts are in the container they should work via `docker exec` like so:

* `docker exec pihole_container_name whitelist.sh some-good-domain.com`
* `docker exec pihole_container_name blacklist.sh some-bad-domain.com`

