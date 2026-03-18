# Docker Pi-hole

[![Build Status](https://github.com/pi-hole/docker-pi-hole/workflows/Build%20Image%20and%20Test/badge.svg)](https://github.com/pi-hole/docker-pi-hole/actions?query=workflow%3A%22Build+Image+and+Test%22) [![Docker Stars](https://img.shields.io/docker/stars/pihole/pihole.svg?maxAge=604800)](https://store.docker.com/community/images/pihole/pihole) [![Docker Pulls](https://img.shields.io/docker/pulls/pihole/pihole.svg?maxAge=604800)](https://store.docker.com/community/images/pihole/pihole)

<div align="center">
  <a href="https://pi-hole.net/">
    <img src="https://pi-hole.github.io/graphics/Vortex/vortex_with_text.svg" width="144" height="256" alt="Pi-hole website">
  </a>
  <br>
  <strong>Network-wide ad blocking via your own Linux hardware</strong>
  <br>
  <br>
  <div align="center">
    <a href="https://pi-hole.net/">Pi-hole website</a> |
    <a href="https://docs.pi-hole.net/">Documentation</a> |
    <a href="https://discourse.pi-hole.net/">Discourse Forum</a> |
    <a href="https://pi-hole.net/donate">Donate</a>
  </div>
  <br>
  <br>
</div>
<!-- Delete above HTML and insert markdown for dockerhub : ![Pi-hole](https://pi-hole.github.io/graphics/Vortex/Vortex_with_text.png) -->

## Upgrade Notes

> [!NOTE]
> **Using Watchtower?\
> See the [Note on Watchtower](https://docs.pi-hole.net/docker/tips-and-tricks/#note-on-watchtower) in our documentation**.

> [!TIP]
> Some users [have reported issues](https://github.com/pi-hole/docker-pi-hole/issues/963#issuecomment-1095602502) with using the `--privileged` flag on `2022.04` and above.\
> TL;DR, don't use that mode, and be [explicit with the permitted caps](https://docs.pi-hole.net/docker/#note-on-capabilities) (if needed) instead.

## Quick Start

Using [Docker-compose](https://docs.docker.com/compose/install/):

1. Copy the below docker compose example and update as needed:

```yml
# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      # DNS Ports
      - "53:53/tcp"
      - "53:53/udp"
      # Default HTTP Port
      - "80:80/tcp"
      # Default HTTPs Port. FTL will generate a self-signed certificate
      - "443:443/tcp"
      # Uncomment the line below if you are using Pi-hole as your DHCP server
      #- "67:67/udp"
      # Uncomment the line below if you are using Pi-hole as your NTP server
      #- "123:123/udp"
    environment:
      # Set the appropriate timezone for your location (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), e.g:
      TZ: 'Europe/London'
      # Set a password to access the web interface. Not setting one will result in a random password being assigned
      FTLCONF_webserver_api_password: 'correct horse battery staple'
      # If using Docker's default `bridge` network setting the dns listening mode should be set to 'ALL'
      FTLCONF_dns_listeningMode: 'ALL'
    # Volumes store your data between container upgrades
    volumes:
      # For persisting Pi-hole's databases and common configuration file
      - './etc-pihole:/etc/pihole'
      # Uncomment the below if you have custom dnsmasq config files that you want to persist. Not needed for most starting fresh with Pi-hole v6. If you're upgrading from v5 you and have used this directory before, you should keep it enabled for the first v6 container start to allow for a complete migration. It can be removed afterwards. Needs environment variable FTLCONF_misc_etc_dnsmasq_d: 'true'
      #- './etc-dnsmasq.d:/etc/dnsmasq.d'
    cap_add:
      # See https://docs.pi-hole.net/docker/#note-on-capabilities
      # Required if you are using Pi-hole as your DHCP server, else not needed
      - NET_ADMIN
      # Required if you are using Pi-hole as your NTP client to be able to set the host's system time
      - SYS_TIME
      # Optional, if Pi-hole should get some more processing time
      - SYS_NICE
    restart: unless-stopped
```

2. Run `docker compose up -d` to build and start pi-hole (Syntax may be `docker-compose` on older systems).

> [!NOTE]
> Volumes are recommended for persisting data across container re-creations for updating images.

### Automatic Ad List Updates

`cron` is baked into the container and will grab the newest versions of your lists and flush your logs. This happens once per week in the small hours of Sunday morning.

## Documentation

For more detailed information, please refer to our documentation:

- [Running DHCP from Docker Pi-Hole](https://docs.pi-hole.net/docker/DHCP/)
- [Configuration](https://docs.pi-hole.net/docker/configuration/)
- [Tips and Tricks](https://docs.pi-hole.net/docker/tips-and-tricks/)
- [Docker tags and versioning](https://docs.pi-hole.net/docker/#docker-tags-and-versioning)
- [Upgrading, Persistence, and Customizations](https://docs.pi-hole.net/docker/upgrading/)

## Docker tags and versioning

The primary docker tags are explained in the following table.  [Click here to see the full list of tags](https://hub.docker.com/r/pihole/pihole/tags). See [GitHub Release notes](https://github.com/pi-hole/docker-pi-hole/releases) to see the specific version of Pi-hole Core, Web, and FTL included in the release.

The Date-based (including incremented "Patch" versions) do not relate to any kind of semantic version number, rather a date is used to differentiate between the new version and the old version, nothing more.

Release notes will always contain full details of changes in the container, including changes to core Pi-hole components.

| tag | description |
| :--- | :--- |
| `latest` | Always the latest release |
| `2022.04.0` | Date-based release |
| `nightly` | Built and pushed whenever there are changes on the `development` branch and additionally produced by the scheduled nightly job. These are the most experimental development images and may change frequently |

## User Feedback

Please report issues on the [GitHub project](https://github.com/pi-hole/docker-pi-hole) when you suspect something docker related.  Pi-hole or general docker questions are best answered on our [user forums](https://discourse.pi-hole.net/c/bugs-problems-issues/docker/30)
