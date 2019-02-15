Please note the following about this [traefik](https://traefik.io/) example for Docker Pi-hole

- Still requires standard Pi-hole setup steps, make sure you've gone through the [README](https://github.com/pihole/docker-pi-hole/blob/master/README.md) and understand how to setup Pi-hole without traefik first
- Update these things before using:
    - set instances of `homedomain.lan` below to your home domain (typically set in your router)
    - set your Pi-hole ENV WEBPASSWORD if you don't want a random admin pass
- This works for me, Your mileage may vary!
- For support, do your best to figure out traefik issues on your own:
    - by looking at logs and traefik web interface on port 8080
    - also by searching the web and searching their forums/docker issues for similar question/problems
- Port 8053 is mapped directly to Pi-hole to serve as a back door without going through traefik
- There is some delay after starting your container before traefik forwards the HTTP traffic correctly, give it a minute

```
version: '3'

services:
  #
  traefik:
    container_name: traefik
    domainname: homedomain.lan

    image: traefik
    restart: unless-stopped
    # Note I opt to whitelist certain apps for exposure to traefik instead of auto discovery
    # use `--docker.exposedbydefault=true` if you don't want to have to do this
    command: "--web --docker --docker.domain=homedomain.lan --docker.exposedbydefault=false --logLevel=DEBUG"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /dev/null:/traefik.toml
    networks:
      - default
      - discovery
    dns:
      - 192.168.1.50
      - 192.168.1.1

  pihole:
    container_name: pihole
    domainname: homedomain.lan

    image: pihole/pihole:latest
    dns:
      - 127.0.0.1
      - 1.1.1.1
    ports:
      - '0.0.0.0:53:53/tcp'
      - '0.0.0.0:53:53/udp'
      - '0.0.0.0:67:67/udp'
      - '0.0.0.0:8053:80/tcp'
    volumes:
      - ./etc-pihole/:/etc/pihole/
      - ./etc-dnsmasqd/:/etc/dnsmasq.d/
      # run `touch ./pihole.log` first unless you like errors
      # - ./pihole.log:/var/log/pihole.log
    environment:
      ServerIP: 192.168.1.50
      PROXY_LOCATION: pihole
      VIRTUAL_HOST: pihole.homedomain.lan
      VIRTUAL_PORT: 80
      TZ: 'America/Chicago'
      # WEBPASSWORD:
    restart: unless-stopped
    labels:
       # required when using --docker.exposedbydefault=false
       - "traefik.enable=true"
       # https://www.techjunktrunk.com/docker/2017/11/03/traefik-default-server-catch-all/
       - "traefik.frontend.rule=HostRegexp:pihole.homedomain.lan,{catchall:.*}"
       - "traefik.frontend.priority=1"
       - "traefik.backend=pihole"
       - "traefik.port=80"

networks:
  # Discovery is manually created to avoid forcing any order of docker-compose stack creation (`docker network create discovery`)
  # allows other compose files to be seen by proxy
  # Not required if you aren't using multiple docker-compose files...
  discovery:
    external: true
```

After running `docker-compose up -d` you should see this if you look at logs on traefik `docker-compose logs -f traefik`

```
traefik    | time="2018-03-07T18:57:41Z" level=debug msg="Provider event received {Status:health_status: healthy ID:33567e94e02c5adba3d47fa44c391e94fdea359fb05eecb196c95de288ffb861 From:pihole/pihole:latest Type:container Action:health_status: healthy Actor:{ID:33567e94
e02c5adba3d47fa44c391e94fdea359fb05eecb196c95de288ffb861 Attributes:map[com.docker.compose.project:traefik image:pihole/pihole:latest traefik.frontend.priority:1 com.docker.compose.container-number:1 com.docker.compose.service:pihole com.docker.compose.version:1.19.0 name:pihole traefik.enable:true url:https://www.github.com/pihole/docker-pi-hole com.docker.compose.oneoff:False maintainer:adam@diginc.us traefik.backend:pihole traefik.frontend.rule:HostRegexp:pihole.homedomain.lan,{catchall:.*} traefik.port:80 com.docker.compose.config-
hash:7551c3f4bd11766292c7dad81473ef21da91cae8666d1b04a42d1daab53fba0f]} Scope:local Time:1520449061 TimeNano:1520449061934970670}"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Filtering disabled container /traefik"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Could not load traefik.frontend.whitelistSourceRange labels"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Could not load traefik.frontend.entryPoints labels"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Could not load traefik.frontend.auth.basic labels"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Validation of load balancer method for backend backend-pihole failed: invalid load-balancing method ''. Using default method wrr."
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Configuration received from provider docker: {"backends":{"backend-pihole":{"servers":{"server-pihole":{"url":"http://172.18.0.2:80","weight":0}},"loadBalancer":{"method":"wrr"}}},"frontends":{"frontend-HostRegexp
-pihole-homedomain-lan-catchall-0":{"entryPoints":["http"],"backend":"backend-pihole","routes":{"route-frontend-HostRegexp-pihole-homedomain-lan-catchall-0":{"rule":"HostRegexp:pihole.homedomain.lan,{catchall:.*}"}},"passHostHeader":true,"priority":1,"basicAuth":[]}}}"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Creating frontend frontend-HostRegexp-pihole-homedomain-lan-catchall-0"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Wiring frontend frontend-HostRegexp-pihole-homedomain-lan-catchall-0 to entryPoint http"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Creating route route-frontend-HostRegexp-pihole-homedomain-lan-catchall-0 HostRegexp:pihole.homedomain.lan,{catchall:.*}"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Creating backend backend-pihole"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Creating load-balancer wrr"
traefik    | time="2018-03-07T18:57:42Z" level=debug msg="Creating server server-pihole at http://172.18.0.2:80 with weight 0"
traefik    | time="2018-03-07T18:57:42Z" level=info msg="Server configuration reloaded on :80"
traefik    | time="2018-03-07T18:57:42Z" level=info msg="Server configuration reloaded on :8080"
```

Also your port 8080 should list the Route/Rule for pihole and backend-pihole container.
