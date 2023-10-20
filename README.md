# Docker Pi-hole

<p align="center">
<a href="https://pi-hole.net"><img src="https://pi-hole.github.io/graphics/Vortex/Vortex_with_text.png" width="150" height="255" alt="Pi-hole"></a><br/>
</p>
<!-- Delete above HTML and insert markdown for dockerhub : ![Pi-hole](https://pi-hole.github.io/graphics/Vortex/Vortex_with_text.png) -->

## Upgrade Notes

## !!! THIS VERSION CONTAINS BREAKING CHANGES

### v[ChangeMeBeforeTagging] has been entirely redesigned from the ground up and contains many breaking changes. Environment variable names have changed, script locations may have changed. Please read the the Readme carefully before proceeding

---

- **Using Watchtower? See the [Note on Watchtower](#note-on-watchtower) at the bottom of this readme**

- Some users [have reported issues](https://github.com/pi-hole/docker-pi-hole/issues/963#issuecomment-1095602502) with using the `--privileged` flag on `2022.04` and above. TL;DR, don't use that mode, and be [explicit with the permitted caps](https://github.com/pi-hole/docker-pi-hole#note-on-capabilities) (if needed) instead

## Quick Start

1. Copy docker-compose.yml.example to docker-compose.yml and update as needed. See example below:
[Docker-compose](https://docs.docker.com/compose/install/) example:

```yaml
version: "3"

# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    # For DHCP it is recommended to remove these ports and instead add: network_mode: "host"
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp" # Only required if you are using Pi-hole as your DHCP server
      - "80:80/tcp"
      - "443:443/tcp" # By default, FTL will generate a self-signed certificate
    environment:
      TZ: 'America/Chicago'
      # FTLCONF_webserver_api_password: 'set a secure password here or it will be random'
    # Volumes store your data between container upgrades
    volumes:
      - './etc-pihole:/etc/pihole'
     # - './etc-dnsmasq.d:/etc/dnsmasq.d' # Only needed if you have some custom configs for dnsmasq
    # https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
    cap_add:
      - NET_ADMIN # Required if you are using Pi-hole as your DHCP server, else not needed
    restart: unless-stopped
```

2. Run `docker compose up -d` to build and start pi-hole (Syntax may be `docker-compose` on older systems)
3. If using Docker's default `bridge` network setting, set the environment variable `FTLCONF_dns_listeningMode` to `all`

[Here is an equivalent docker run script](https://github.com/pi-hole/docker-pi-hole/blob/master/examples/docker_run.sh).

## Overview

A [Docker](https://www.docker.com/what-docker) project to make a lightweight x86 and ARM container with [Pi-hole](https://pi-hole.net) functionality.

1) Install Docker. [Docker-compose](https://docs.docker.com/compose/install/) is also recommended.
2) Use the above quick start example, customize if desired.
3) Enjoy!

[![Build Status](https://github.com/pi-hole/docker-pi-hole/workflows/Test%20&%20Build/badge.svg)](https://github.com/pi-hole/docker-pi-hole/actions?query=workflow%3A%22Test+%26+Build%22) [![Docker Stars](https://img.shields.io/docker/stars/pihole/pihole.svg?maxAge=604800)](https://store.docker.com/community/images/pihole/pihole) [![Docker Pulls](https://img.shields.io/docker/pulls/pihole/pihole.svg?maxAge=604800)](https://store.docker.com/community/images/pihole/pihole)

## Running Pi-hole Docker

This container uses 2 popular ports, port 53 and port 80, so **may conflict with existing applications ports**.  If you have no other services or docker containers using port 53/80 (if you do, keep reading below for a reverse proxy example), the minimum arguments required to run this container are in the script [docker_run.sh](https://github.com/pi-hole/docker-pi-hole/blob/master/examples/docker_run.sh)

If you're using a Red Hat based distribution with an SELinux Enforcing policy add `:z` to line with volumes like so:

```
    -v "$(pwd)/etc-pihole:/etc/pihole:z" \
```

Volumes are recommended for persisting data across container re-creations for updating images.

**Automatic Ad List Updates** - `cron` is baked into the container and will grab the newest versions of your lists and flush your logs. This happens once per week in the small hours of Sunday morning.

## Running DHCP from Docker Pi-Hole

There are multiple different ways to run DHCP from within your Docker Pi-hole container but it is slightly more advanced and one size does not fit all. DHCP and Docker's multiple network modes are covered in detail on our docs site: [Docker DHCP and Network Modes](https://docs.pi-hole.net/docker/DHCP/)

## Configuration

It is recommended that you use environment variables to configure the Pi-hole docker container (more details below), however if you are persisting your `/etc/pihole` directory, you may also set them via the web interface or by directly editing `pihole.toml`

### Web interface password

To set a specific password for the web interface, use the environment variable `FTLCONF_webserver_api_password`. If this variable is not detected, and you have not already set one via `pihole setpassword` in the container, then a random password will be assigned on startup, this will be printed to the log. Run `docker logs pihole | grep random` to find it.

To explicitly set no password, set `FTLCONF_webserver_api_password: ''`

### Recommended Environment Variables

| Variable | Default | Value | Description |
| -------- | ------- | ----- | ---------- |
| `TZ` | UTC | `<Timezone>` | Set your [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) to make sure logs rotate at local midnight instead of at UTC midnight.
| `FTLCONF_webserver_api_password` | random | `<Admin password>` | <http://pi.hole/admin> password. Run `docker logs pihole \| grep random` to find your random pass.
| `FTLCONF_dns_upstreams` |  `8.8.8.8,8.8.4.4` | IPs delimited by `,` | Upstream DNS server(s) for Pi-hole to forward queries to, separated by a semicolon <br/> (supports non-standard ports with `#[port number]`) e.g `127.0.0.1#5053,8.8.8.8,8.8.4.4` <br/> (supports [Docker service names and links](https://docs.docker.com/compose/networking/) instead of IPs) e.g `upstream0,upstream1` where `upstream0` and `upstream1` are the service names of or links to docker services <br/> Note: The existence of this environment variable assumes this as the _sole_ management of upstream DNS. Upstream DNS added via the web interface will be overwritten on container restart/recreation |

### Optional Variables

| Variable | Default | Value | Description |
| -------- | ------- | ----- | ---------- |
| `TAIL_FTL_LOG` | unset | `<unset\|1>` | Whether or not to output the FTL log when running the. Useful for debugging/watching what FTL is doing.
| `SKIPGRAVITYONBOOT` | unset | `<unset\|1>` | Use this option to skip updating the Gravity Database when booting up the container.  By default this environment variable is not set so the Gravity Database will be updated when the container starts up.  Setting this environment variable to 1 (or anything) will cause the Gravity Database to not be updated when container starts up.
| `FTLCONF_[SETTING]` | unset | As per documentation | Customize pihole-FTL.conf with settings described in the <!!!Add Link To New API docs here before release!!!>. Replace `.` with `_`, e.g for `dns.dnssec=true` use `FTLCONF_dns_dnssec: 'true'`|
| `PIHOLE_UID` | `100` | Number | Overrides image's default pihole user id to match a host user id<br/>**IMPORTANT**: id must not already be in use inside the container! |
| `PIHOLE_GID` | `101` | Number | Overrides image's default pihole group id to match a host group id<br/>**IMPORTANT**: id must not already be in use inside the container!|

### Advanced Variables

| Variable | Default | Value | Description |
| -------- | ------- | ----- | ---------- |
| `FTL_CMD` | `no-daemon` | `no-daemon -- <dnsmasq option>` | Customize the options with which dnsmasq gets started. e.g. `no-daemon -- --dns-forward-max 300` to increase max. number of concurrent dns queries on high load setups. |
|`FTLCONF_ENV_ONLY`|unset|`<true\|false>`|If set to true, FTL will use default values for all config values unless explicitly set as an environment variable|
| `DNSMASQ_USER` | unset | `<pihole\|root>` | Allows changing the user that FTLDNS runs as. Default: `pihole`, some systems such as Synology NAS may require you to change this to `root` (See [#963](https://github.com/pi-hole/docker-pi-hole/issues/963)) |
| `ADDITIONAL_PACKAGES`| unset | Space separated list of APKs | HERE BE DRAGONS. Mostly for development purposes, this just makes it easier for those of us that always like to have whatever additional tools we need inside the container for debugging |

Here is a rundown of other arguments for your docker-compose / docker run.

| Docker Arguments | Description |
| ---------------- | ----------- |
| `-p <port>:<port>` **Recommended** | Ports to expose (53, 80, 67), the bare minimum ports required for Pi-holes HTTP and DNS services
| `--restart=unless-stopped`<br/> **Recommended** | Automatically (re)start your Pi-hole on boot or in the event of a crash
| `-v $(pwd)/etc-pihole:/etc/pihole`<br/> **Recommended** | Volumes for your Pi-hole configs help persist changes across docker image updates
| `--net=host`<br/> _Optional_ | Alternative to `-p <port>:<port>` arguments (Cannot be used at same time as -p) if you don't run any other web application. DHCP runs best with --net=host, otherwise your router must support dhcp-relay settings.
| `--cap-add=NET_ADMIN`<br/> _Recommended_ | Commonly added capability for DHCP, see [Note on Capabilities](#note-on-capabilities) below for other capabilities.
| `--dns=127.0.0.1`<br/> _Optional_ | Sets your container's resolve settings to localhost so it can resolve DHCP hostnames from Pi-hole's DNSMasq, may fix resolution errors on container restart.
| `--dns=1.1.1.1`<br/> _Optional_ | Sets a backup server of your choosing in case DNSMasq has problems starting
| `--env-file .env` <br/> _Optional_ | File to store environment variables for docker replacing `-e key=value` settings. Here for convenience

## Tips and Tricks

- A good way to test things are working right is by loading this page: [http://pi.hole/admin/](http://pi.hole/admin/)
- Port conflicts?  Stop your server's existing DNS / Web services.
  - Don't forget to stop your services from auto-starting again after you reboot
  - Ubuntu users see below for more detailed information
- You can map other ports to Pi-hole port 80 using docker's port forwarding like this `-p 8080:80` if you are using the default blocking mode. If you are using the legacy IP blocking mode, you should not remap this port.
  - [Here is an example of running with nginxproxy/nginx-proxy](https://github.com/pi-hole/docker-pi-hole/blob/master/examples/docker-compose-nginx-proxy.yml) (an nginx auto-configuring docker reverse proxy for docker) on my port 80 with Pi-hole on another port.  Pi-hole needs to be `DEFAULT_HOST` env in nginxproxy/nginx-proxy and you need to set the matching `VIRTUAL_HOST` for the Pi-hole's container.  Please read nginxproxy/nginx-proxy readme for more info if you have trouble.
- Docker's default network mode `bridge` isolates the container from the host's network. This is a more secure setting, but requires setting the Pi-hole DNS option for _Interface listening behavior_ to "Listen on all interfaces, permit all origins".

### Installing on Ubuntu or Fedora

Modern releases of Ubuntu (17.10+) and Fedora (33+) include [`systemd-resolved`](http://manpages.ubuntu.com/manpages/bionic/man8/systemd-resolved.service.8.html) which is configured by default to implement a caching DNS stub resolver. This will prevent pi-hole from listening on port 53.
The stub resolver should be disabled with: `sudo sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf`

This will not change the nameserver settings, which point to the stub resolver thus preventing DNS resolution. Change the `/etc/resolv.conf` symlink to point to `/run/systemd/resolve/resolv.conf`, which is automatically updated to follow the system's [`netplan`](https://netplan.io/):
`sudo sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'`
After making these changes, you should restart systemd-resolved using `systemctl restart systemd-resolved`

Once pi-hole is installed, you'll want to configure your clients to use it ([see here](https://discourse.pi-hole.net/t/how-do-i-configure-my-devices-to-use-pi-hole-as-their-dns-server/245)). If you used the symlink above, your docker host will either use whatever is served by DHCP, or whatever static setting you've configured. If you want to explicitly set your docker host's nameservers you can edit the netplan(s) found at `/etc/netplan`, then run `sudo netplan apply`.
Example netplan:

```yaml
network:
    ethernets:
        ens160:
            dhcp4: true
            dhcp4-overrides:
                use-dns: false
            nameservers:
                addresses: [127.0.0.1]
    version: 2
```

Note that it is also possible to disable `systemd-resolved` entirely. However, this can cause problems with name resolution in vpns ([see bug report](https://bugs.launchpad.net/network-manager/+bug/1624317)). It also disables the functionality of netplan since systemd-resolved is used as the default renderer ([see `man netplan`](http://manpages.ubuntu.com/manpages/bionic/man5/netplan.5.html#description)). If you choose to disable the service, you will need to manually set the nameservers, for example by creating a new `/etc/resolv.conf`.

Users of older Ubuntu releases (circa 17.04) will need to disable dnsmasq.

## Installing on Dokku

@Rikj000 has produced a guide to assist users [installing Pi-hole on Dokku](https://github.com/Rikj000/Pihole-Dokku-Installation)

## Docker tags and versioning

The primary docker tags are explained in the following table.  [Click here to see the full list of tags](https://store.docker.com/community/images/pihole/pihole/tags). See [GitHub Release notes](https://github.com/pi-hole/docker-pi-hole/releases) to see the specific version of Pi-hole Core, Web, and FTL included in the release.

The Date-based (including incremented "Patch" versions) do not relate to any kind of semantic version number, rather a date is used to differentiate between the new version and the old version, nothing more. Release notes will always contain full details of changes in the container, including changes to core Pi-hole components

| tag                 | description
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| `latest`            | Always latest release                                                                                                                      |
| `2022.04`           | Date-based release                                                                                                                         |
| `2022.04.1`         | Second release in a given month                                                                                                            |
| `dev`               | Similar to `latest`, but for the development branch (pushed occasionally)                                                                  |
| `*beta`             | Early beta releases of upcoming versions - here be dragons                                                                                 |
| `nightly`           | Like `dev` but pushed every night and pulls from the latest `development` branches of the core Pi-hole components (Pi-hole, web, FTL)      |

## Upgrading, Persistence, and Customizations

The standard Pi-hole customization abilities apply to this docker, but with docker twists such as using docker volume mounts to map host stored file configurations over the container defaults.  However, mounting these configuration files as read-only should be avoided.  Volumes are also important to persist the configuration in case you have removed the Pi-hole container which is a typical docker upgrade pattern.

### Upgrading / Reconfiguring

Do not attempt to upgrade (`pihole -up`) or reconfigure (`pihole -r`).  New images will be released for upgrades, upgrading by replacing your old container with a fresh upgraded image is the 'docker way'.  Long-living docker containers are not the docker way since they aim to be portable and reproducible, why not re-create them often!  Just to prove you can.

0. Read the release notes for both this Docker release and the Pi-hole release
    - This will help you avoid common problems due to any known issues with upgrading or newly required arguments or variables
    - We will try to put common break/fixes at the top of this readme too
1. Download the latest version of the image: `docker pull pihole/pihole`
2. Throw away your container: `docker rm -f pihole`
    - **Warning** When removing your pihole container you may be stuck without DNS until step 3; **docker pull** before **docker rm -f** to avoid DNS interruption **OR** always have a fallback DNS server configured in DHCP to avoid this problem altogether.
    - If you care about your data (logs/customizations), make sure you have it volume-mapped or it will be deleted in this step.
3. Start your container with the newer base image: `docker run <args> pihole/pihole` (`<args>` being your preferred run volumes and env vars)

Why is this style of upgrading good?  A couple reasons: Everyone is starting from the same base image which has been tested to known it works.  No worrying about upgrading from A to B, B to C, or A to C is required when rolling out updates, it reduces complexity, and simply allows a 'fresh start' every time while preserving customizations with volumes.  Basically I'm encouraging [phoenix server](https://www.google.com/?q=phoenix+servers) principles for your containers.

To reconfigure Pi-hole you'll either need to use an existing container environment variables or if there is no a variable for what you need, use the web UI or CLI commands.

### Building an image with alternative component branches

Occasionally you may need to try an alternative branch of one of the components (`core`,`web`,`ftl`). On bare metal you would run, for example, `pihole checkout core custombranchname`, however in Docker world we have disabled this command as it can cause unpredictable results.

The preferred method is to clone this repository and rebuild the image with the custom branch name passed in as an arg, e.g `docker buildx build src/. --tag pihole_custom --build-arg CORE_BRANCH=custombranchname --no-cache`, and then redeploy your stack with this new image (In this case you should have a local image named `pihole_custom`, but you can call it whatever you want)

Valid args are:

- `CORE_BRANCH`
- `WEB_BRANCH`
- `FTL_BRANCH`

### Pi-hole features

Here are some relevant wiki pages from [Pi-hole's documentation](https://github.com/pi-hole/pi-hole/blob/master/README.md#get-help-or-connect-with-us-on-the-web).  The web interface or command line tools can be used to implement changes to pihole.

We install all pihole utilities so the the built in [pihole commands](https://discourse.pi-hole.net/t/the-pihole-command-with-examples/738) will work via `docker exec <container> <command>` like so:

- `docker exec pihole_container_name pihole updateGravity`
- `docker exec pihole_container_name pihole -w spclient.wg.spotify.com`
- `docker exec pihole_container_name pihole -wild example.com`

### Customizations

The webserver and DNS service inside the container can be customized if necessary.  Any configuration files you volume mount into `/etc/dnsmasq.d/` will be loaded by dnsmasq when the container starts or restarts or if you need to modify the Pi-hole config it is located at `/etc/dnsmasq.d/01-pihole.conf`.  The docker start scripts runs a config test prior to starting so it will tell you about any errors in the docker log.

## Note on Capabilities

DNSMasq / [FTLDNS](https://docs.pi-hole.net/ftldns/in-depth/#linux-capabilities) expects to have the following capabilities available:

- `CAP_NET_BIND_SERVICE`: Allows FTLDNS binding to TCP/UDP sockets below 1024 (specifically DNS service on port 53)
- `CAP_NET_RAW`: use raw and packet sockets (needed for handling DHCPv6 requests, and verifying that an IP is not in use before leasing it)
- `CAP_NET_ADMIN`: modify routing tables and other network-related operations (in particular inserting an entry in the neighbor table to answer DHCP requests using unicast packets)
- `CAP_SYS_NICE`: FTL sets itself as an important process to get some more processing time if the latter is running low
- `CAP_CHOWN`: we need to be able to change ownership of log files and databases in case FTL is started as a different user than `pihole`

This image automatically grants those capabilities, if available, to the FTLDNS process, even when run as non-root.\
By default, docker does not include the `NET_ADMIN` capability for non-privileged containers, and it is recommended to explicitly add it to the container using `--cap-add=NET_ADMIN`.\
However, if DHCP and IPv6 Router Advertisements are not in use, it should be safe to skip it. For the most paranoid, it should even be possible to explicitly drop the `NET_RAW` capability to prevent FTLDNS from automatically gaining it.

## Note on Watchtower

We have noticed that a lot of people use Watchtower to keep their Pi-hole containers up to date. For the same reason we don't provide an auto-update feature on a bare metal install, you _should not_ have a system automatically update your Pi-hole container. Especially unattended. As much as we try to ensure nothing will go wrong, sometimes things do go wrong - and you need to set aside time to _manually_ pull and update to the version of the container you wish to run. The upgrade process should be along the lines of:

- **Important**: Read the release notes. Sometimes you will need to make changes other than just updating the image
- Pull the new image
- Stop and _remove_ the running Pi-hole container
  - If you care about your data (logs/customizations), make sure you have it volume-mapped or it will be deleted in this step.
- Recreate the container using the new image

Pi-hole is an integral part of your network, don't let it fall over because of an unattended update in the middle of the night.

# User Feedback

Please report issues on the [GitHub project](https://github.com/pi-hole/docker-pi-hole) when you suspect something docker related.  Pi-hole or general docker questions are best answered on our [user forums](https://discourse.pi-hole.net/c/bugs-problems-issues/docker/30).
