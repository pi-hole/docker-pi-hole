Please note the following about this [traefik](https://traefik.io/) example for Docker Pi-hole

- Still requires standard Pi-hole setup steps, make sure you've gone through the [README](https://github.com/pi-hole/docker-pi-hole/blob/master/README.md) and understand how to setup Pi-hole without traefik first
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
version: '3.8'

services:
  traefik:
    container_name: traefik
    domainname: homedomain.lan

    image: traefik
    restart: unless-stopped
    # Note I opt to whitelist certain apps for exposure to traefik instead of auto discovery
    # use `--providers.docker.exposedbydefault=true` if you don't want to have to do this
    command:
      - "--providers.docker=true"
      - "--providers.docker.network=web"
      - "--providers.docker.exposedbydefault=false"
      - "--api.insecure=true"
      - "--api.dashboard=true"
      - "--entrypoints.http.address=:80"
      - "--log.level=DEBUG"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /dev/null:/traefik.toml
    networks:
      - default
      - web
    dns:
      - 192.168.1.50
      - 192.168.1.1

  pihole:
    container_name: pihole
    domainname: homedomain.lan

    image: pihole/pihole:latest
    networks:
      - web
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
       # required when using --providers.docker.exposedbydefault=false
       - "traefik.enable=true"
       - "traefik.http.routers.pihole.rule=PathPrefix(`/`)"
       - "traefik.http.routers.pihole.entrypoints=http"
       - "traefik.docker.network=web"
       - "traefik.http.services.pihole.loadbalancer.server.port=80"

networks:
  # Discovery is manually created to avoid forcing any order of docker-compose stack creation (`docker network create discovery`)
  # allows other compose files to be seen by proxy
  # Not required if you aren't using multiple docker-compose files...
  web:
    external: true
```

After running `docker-compose up -d` you should see this if you look at logs on traefik `docker-compose logs -f traefik`

```
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Provider event received {Status:health_status: healthy ID:daf190c70930ec8830213a4e3b710ae558048798dd7229885eedd92a05a25df8 From:pihole/pihole:latest Type:container Action:health_status: healthy Actor:{ID:daf190c70930ec8830213a4e3b710ae558048798dd7229885eedd92a05a25df8 Attributes:map[com.docker.compose.config-hash:6195e8f8f24f1eb3a4866cb02407813596401b91939149c71b5fb8ecfefbaab5 com.docker.compose.container-number:1 com.docker.compose.oneoff:False com.docker.compose.project:pi-hole com.docker.compose.project.config_files:docker-compose.yml com.docker.compose.project.working_dir:/opt/pi-hole com.docker.compose.service:pihole com.docker.compose.version:1.25.5 image:pihole/pihole:latest maintainer:adam@diginc.us name:pihole traefik.docker.network:web traefik.enable:true traefik.http.routers.pihole.entrypoints:http traefik.http.routers.pihole.rule:PathPrefix(`/`) traefik.http.services.pihole.loadbalancer.server.port:80 url:https://www.github.com/pi-hole/docker-pi-hole]} Scope:local Time:1588514476 TimeNano:1588514476657434084}" providerName=docker
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Filtering disabled container" providerName=docker container=traefik-pi-hole-67c8ac28f250dc960da708895724a9d5753b9797f8fa4af599898c364673eaab
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Configuration received from provider docker: {\"http\":{\"routers\":{\"pihole\":{\"entryPoints\":[\"http\"],\"service\":\"pihole\",\"rule\":\"PathPrefix(`/`)\"}},\"services\":{\"pihole\":{\"loadBalancer\":{\"servers\":[{\"url\":\"http://172.26.0.3:80\"}],\"passHostHeader\":true}}}},\"tcp\":{},\"udp\":{}}" providerName=docker
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Added outgoing tracing middleware api@internal" routerName=api@internal middlewareName=tracing middlewareType=TracingForwarder entryPointName=traefik
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Added outgoing tracing middleware dashboard@internal" middlewareType=TracingForwarder entryPointName=traefik routerName=dashboard@internal middlewareName=tracing
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating middleware" routerName=dashboard@internal middlewareName=dashboard_stripprefix@internal middlewareType=StripPrefix entryPointName=traefik
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Adding tracing to middleware" entryPointName=traefik routerName=dashboard@internal middlewareName=dashboard_stripprefix@internal
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating middleware" routerName=dashboard@internal middlewareName=dashboard_redirect@internal middlewareType=RedirectRegex entryPointName=traefik
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Setting up redirection from ^(http:\\/\\/[^:\\/]+(:\\d+)?)\\/$ to ${1}/dashboard/" entryPointName=traefik routerName=dashboard@internal middlewareName=dashboard_redirect@internal middlewareType=RedirectRegex
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Adding tracing to middleware" entryPointName=traefik routerName=dashboard@internal middlewareName=dashboard_redirect@internal
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating middleware" middlewareName=traefik-internal-recovery middlewareType=Recovery entryPointName=traefik
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating middleware" routerName=pihole@docker serviceName=pihole middlewareName=pipelining middlewareType=Pipelining entryPointName=http
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating load-balancer" entryPointName=http routerName=pihole@docker serviceName=pihole
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating server 0 http://172.26.0.3:80" serviceName=pihole serverName=0 entryPointName=http routerName=pihole@docker
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Added outgoing tracing middleware pihole" middlewareType=TracingForwarder entryPointName=http routerName=pihole@docker middlewareName=tracing
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="Creating middleware" entryPointName=http middlewareName=traefik-internal-recovery middlewareType=Recovery
traefik    | time="2020-05-03T14:01:16Z" level=debug msg="No default certificate, generating one"
```

Also your port 8080 should list the Route/Rule for pihole and backend-pihole container.
