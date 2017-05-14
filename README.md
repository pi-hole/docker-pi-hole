A [Docker](https://www.docker.com/what-docker) project to make lightweight x86 and ARM container with [pi-hole](https://pi-hole.net) functionality.  Why?  Maybe you don't have a Raspberry Pi lying around but you do have a Docker server.

**Now with ARM (actual docker-pi) support!**  Just install docker on your Rasberry-Pi and run docker image `diginc/pi-hole:arm` tag (see below for full required command).

* The current Raspbian install is simply `curl -sSL https://get.docker.com | sh` [[1]](https://www.raspberrypi.org/blog/docker-comes-to-raspberry-pi/)

[![Build Status](https://api.travis-ci.org/diginc/docker-pi-hole.svg?branch=master)](https://travis-ci.org/diginc/docker-pi-hole) [![Docker Stars](https://img.shields.io/docker/stars/diginc/pi-hole.svg?maxAge=604800)](https://store.docker.com/community/images/diginc/pi-hole) [![Docker Pulls](https://img.shields.io/docker/pulls/diginc/pi-hole.svg?maxAge=604800)](https://store.docker.com/community/images/diginc/pi-hole)

[![Join the chat at https://gitter.im/diginc/docker-pi-hole](https://badges.gitter.im/diginc/docker-pi-hole.svg)](https://gitter.im/diginc/docker-pi-hole?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Running Pi-Hole Docker

[DockerCloud](https://store.docker.com/community/images/diginc/pi-hole) automatically builds the latest docker-pi-hole changes into images which can easily be pulled and ran with a simple `docker run` command.

One crucial thing to know before starting is the docker-pi-hole container needs port 53 and port 80, 2 very popular ports that may conflict with existing applications.  If you have no other services or dockers using port 53/80 (if you do, keep reading below for a reverse proxy example), the minimum options required to run this container are in the script [docker_run.sh](https://github.com/diginc/docker-pi-hole/blob/master/docker_run.sh) or summarized here:

```
IMAGE='diginc/pi-hole'
IP_LOOKUP="$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')"  # May not work for VPN / tun0
IPv6_LOOKUP="$(ip -6 route get 2001:4860:4860::8888 | awk '{ print $10; exit }')"  # May not work for VPN / tun0
IP="${IP:-$IP_LOOKUP}"  # use $IP, if set, otherwise IP_LOOKUP
IPv6="${IPv6:-$IPv6_LOOKUP}"  # use $IPv6, if set, otherwise IP_LOOKUP
docker run -p 53:53/tcp -p 53:53/udp -p 80:80 --cap-add=NET_ADMIN -e ServerIP="$IP" -e ServerIPv6="$IPv6" --restart=always --name pihole -d $IMAGE

# Recommended auto ad list updates & log rotation:
wget -O- https://raw.githubusercontent.com/diginc/docker-pi-hole/master/docker-pi-hole.cron | sudo tee /etc/cron.d/docker-pi-hole
```

This is just an example and might need changing.  As mentioned on line 2, the auto IP_LOOKUP variable may not work for VPN tunnel interfaces.

**Automatic Ad List Updates** - [docker-pi-hole.cron](https://github.com/diginc/docker-pi-hole/blob/master/docker-pi-hole.cron) is a modified version of upstream pi-hole's crontab entries using `docker exec` to run the same update scripts inside the docker container.  The cron automatically updates pi-hole ad lists and cleans up pi-hole logs nightly.  If you're not using the `docker run` with `--name pihole` from default container run command be sure to fill in your container's DOCKER_NAME into the variable in the cron file.

## Environment Variables

In addition to the required environment variable you saw above (`-e ServerIP="$IP"`) there are optional ones if you want to customize various things inside the docker container:

| Env Variable | Default   | Description |
| ------------ | -------   | ----------- |
| ServerIP     | REQUIRED! | Set to your server's external IP in order to override what Pi-Hole users.  Pi-Hole auto discovers the unusable internal docker IP otherwise |
| WEBPASSWORD  | <random>  | Set this to your desired password or on first boot we'll randomly set one.  `docker logs pihole` can tell you what it got set to.  To change it check out the tips below |
| DNS1         | 8.8.8.8   | Primary upstream DNS for Pi-Hole's DNSMasq to use, defaults to google |
| DNS2         | 8.8.4.4   | Secondary upstream DNS for Pi-Hole's DNSMasq to use, defaults to google |
| VIRTUAL_HOST | Server_IP | What your web server 'virtual host' is, accessing admin through this Hostname/IP allows you to make changes to the whitelist / blacklists in addition to the default 'http://pi.hole/admin/' address |
| IPv6         | True      | Allows forced disabling of IPv6 for docker setups that can't support it (like unraid) |

*OPTIONAL Advanced* Environment Variables

| Env Variable | Default   | Description |
| ------------ | -------   | ----------- |
| INTERFACE         | eth0      | The default works fine with our basic example docker run commands.  If you're trying to use DHCP with `--net host` mode then you may have to customize this or DNSMASQ_LISTENING.
| DNSMASQ_LISTENING |             | If set to `local` or `all` this will override `INTERFACE`.  `local` listens on all local subnets, `all` permits listening on internet origin subnets in addition to local.

## Tips and Tricks

* A good way to test things are working right is by loading this page: [http://pi.hole/admin/](http://pi.hole/admin/)
* [How do I set or reset the Web interface Password?](https://discourse.pi-hole.net/t/how-do-i-set-or-reset-the-web-interface-password/1328)
 * `docker exec pihole_container_name pihole -a -p supersecurepassword`
* Port conflicts?  Stop your server's existing DNS / Web services.
 * Ubuntu users especially may need to shutoff dnsmasq on your docker server so it can run in the container on port 53
 * Don't forget to stop your services from auto-starting again after you reboot
* Port 80 is highly recommended because if you have another site/service using port 80 by default then the ads may not transform into blank ads correctly.  To make sure docker-pi-hole plays nicely with an existing webserver you run you'll probably need a reverse proxy webserver config if you don't have one already.  Pi-Hole has to be the default web app on said proxy e.g. if you goto your host by IP instead of domain then pi-hole is served out instead of any other sites hosted by the proxy. This is the '[default_server](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen)' in nginx or ['_default_' virtual host](https://httpd.apache.org/docs/2.4/vhosts/examples.html#default) in Apache and is taken advantage of so any undefined ad domain can be directed to your webserver and get a 'blocked' response instead of ads.
 * You can still map other ports to pi-hole port 80 using docker's port forwarding like this `-p 8080:80`, but again the ads won't render propertly.  Changing the inner port 80 shouldn't be required unless you run docker host networking mode.
 * [Here is an example of running with jwilder/proxy](https://github.com/diginc/docker-pi-hole/blob/master/jwilder-proxy-example-doco.yml) (an nginx auto-configuring docker reverse proxy for docker) on my port 80 with pihole on another port.  Pi-hole needs to be `DEFAULT_HOST` env in jwilder/proxy and you need to set the matching `VIRTUAL_HOST` for the pihole's container.  Please read jwilder/proxy readme for more info if you have trouble.  I tested this basic example which is based off what I run.

## Volume Mounts
Here are some useful volume mount options to persist your history of stats in the admin interface, or add custom whitelists/blacklists.  **Create these files on the docker host first or you'll get errors**:

* `docker run -v /var/log/pihole.log:/var/log/pihole.log ...` (plus all of the minimum options added)
 * `touch /var/log/pihole.log` on your docker server first or you will end up with a directory there (silly docker!)
* `docker run -v /etc/pihole/:/etc/pihole/ ...` (plus all of the minimum options added)

All of these options get really long when strung together in one command, which is why I'm not showing all the full `docker run` commands variations here.  This is where [docker-compose](https://docs.docker.com/compose/install/) yml files come in handy for representing [really long docker commands in a readable file format](https://github.com/diginc/docker-pi-hole/blob/master/doco-example.yml).

## Docker tags and versioning

The primary docker tags / versions are explained in the following table.  [Click here to see the full list of tags](https://store.docker.com/community/images/diginc/pi-hole/tags), I also try to tag with the specific version of Pi-Hole Core for version pinning purposes, the web version that comes with the core releases should be in the [GitHub Release notes](https://github.com/diginc/docker-pi-hole/releases).

| tag                 | architecture | description                                                             | Dockerfile |
| ---                 | ------------ | -----------                                                             | ---------- |
| `alpine` / `latest` | x86          | Alpine x86 image, small size container running nginx and dnsmasq        | [Dockerfile](https://github.com/diginc/docker-pi-hole/blob/master/alpine.docker) |
| `debian`            | x86          | Debian x86 image, container running lighttpd and dnsmasq                | [Dockerfile](https://github.com/diginc/docker-pi-hole/blob/master/debian.docker) |
| `arm`               | ARM          | Debian ARM image, container running lighttpd and dnsmasq built for ARM  | [Dockerfile](https://github.com/diginc/docker-pi-hole/blob/master/debian-armhf.docker) |

### `diginc/pi-hole:alpine` [![](https://images.microbadger.com/badges/image/diginc/pi-hole:alpine.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/version/diginc/pi-hole:alpine.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/version/diginc/pi-hole:latest.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own version badge on microbadger.com")

Alpine is also the default, aka `latest` tag.  If you don't specify a tag you will get this version.  This is only an x86 version and will not work on Raspberry Pi's ARM architecture.  Use this if you like a small image.

### `diginc/pi-hole:debian` [![](https://images.microbadger.com/badges/image/diginc/pi-hole:debian.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/version/diginc/pi-hole:debian.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own version badge on microbadger.com")

This version of the docker aims to be as close to a standard pi-hole installation by using the same base OS and the exact configs and scripts (minimally modified to get them working).  This serves as a stable baseline for merging and testing upstream repository pi-hole changes.  Use this if you don't care about image size and want as stable of a product as possible.

### `diginc/pi-hole:arm` [![](https://images.microbadger.com/badges/image/diginc/pi-hole:arm.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/version/diginc/pi-hole:arm.svg)](https://microbadger.com/images/diginc/pi-hole "Get your own version badge on microbadger.com")

Same as the debian image, but cross compiled for ARM architecture hardware through [resin.io's awesome Qemu wrapper](https://resin.io/blog/building-arm-containers-on-any-x86-machine-even-dockerhub/).

Alpine doesn't have an arm cross compilable image at this time.

## Upgrading, Persistence, and Customizations

The standard pi-hole customization abilities apply to this docker, but with docker twists such as using docker volume mounts to map host stored file configurations over the container defaults.  Volumes are also important to persist the configuration in case you have removed the pi-hole container which is a typical docker upgrade pattern.

### Upgrading

**If you try to use pihole's built in updater it is not guaranteed to work**; it almost assuredly won't work for alpine but debian may.  The preferred 'docker way' to upgrade is: 

1. Download the latest version of the image: `docker pull diginc/pi-hole`
2. Throw away your container: `docker rm -f pihole`
 * **Warning** When removing your pihole container you may be stuck without DNS until step 3 - **docker pull** before you **docker rm -f** to avoid DNS inturruption **OR** always have a fallback DNS server configured in DHCP to avoid this problem all together.
 * If you care about your data (logs/customizations), make sure you have it volume mapped or it will be deleted in this step
3. Start your container with the newer base image: `docker run <args> diginc/pi-hole` (`<args>` being your preferred run volumes and env vars)

Why is this style of upgrading good?  A couple reasons: Everyone is starting from the same base image which has been tested to know it works.  No worrying about upgrading from A to B, B to C, or A to C is required when rolling out updates, it reducing complexity, and simply allows a 'fresh start' every time while preserving customizations with volumes.  Basically I'm encouraging [phoenix servers](https://www.google.com/?q=phoenix+servers) principles for your containers.

### Persisting pihole volume

`-v my-pihole-configs/:/etc/pihole/` Volume mapping the entire /etc/pihole directory is the easiest way to save all your customizations.  Clear out the directory if you want to start from scratch.

### Pihole features

Here are some relevant wiki pages from [pi-hole's documentation](https://github.com/pi-hole/pi-hole/blob/master/README.md#get-help-or-connect-with-us-on-the-web).  The web interface or command line tools can be used to implement changes to pihole.

We install all pihole utilities so the the built in [pihole commands](https://discourse.pi-hole.net/t/the-pihole-command-with-examples/738) will work via `docker exec <container> <command>` like so:

* `docker exec pihole_container_name pihole updateGravity`
* `docker exec pihole_container_name pihole -w spclient.wg.spotify.com
* `docker exec pihole_container_name pihole -wild example.com

### Customizations

The webserver and DNS service inside the container can be customized if necessary.  Any configuration files you volume mount into `/etc/dnsmasq.d/` will be loaded by dnsmasq when the container starts or restarts or if you need to modify the pi-hole config it is located at `/etc/dnsmasq.d/01-pihole.conf`.  The docker start scripts runs a config test prior to starting so it will tell you about any errors in the docker log.

Similarly for the webserver you can customize configs in /etc/nginx (*:alpine* tag) and /etc/lighttpd (*:debian* tag).

## Development [![Build Status](https://api.travis-ci.org/diginc/docker-pi-hole.svg?branch=dev)](https://travis-ci.org/diginc/docker-pi-hole)

If you plan on making a contribution please pull request to the dev branch.  I also build tags of the dev branch for bug fix testing after merges have been made:

| tag                 | architecture | description                                                             | Dockerfile |
| ---                 | ------------ | -----------                                                             | ---------- |
| `alpine_dev`        | x86          | Alpine x86 image, small size container running nginx and dnsmasq        | [Dockerfile](https://github.com/diginc/docker-pi-hole/blob/dev/alpine.docker) |
| `debian_dev`        | x86          | Debian x86 image, container running lighttpd and dnsmasq                | [Dockerfile](https://github.com/diginc/docker-pi-hole/blob/dev/debian.docker) |
| `arm_dev`           | ARM          | Debian ARM image, container running lighttpd and dnsmasq built for ARM  | [Dockerfile](https://github.com/diginc/docker-pi-hole/blob/dev/debian-armhf.docker) |

# User Feedback

Please report issues on the [GitHub project](https://github.com/diginc/docker-pi-hole) when you suspect something docker related.  Pi-Hole questions are best answered on their [user forums](https://github.com/pi-hole/pi-hole/blob/master/README.md#get-help-or-connect-with-us-on-the-web).  Ping me (@diginc) on there if it's a docker and you're not sure if it's docker related.
