# Docker Pi-Hole Examples

In this folder you'll find examples of `ready to go` docker composes files and they're associated configs.
To get started, simply copy the folder with all the files inside it and run `docker compose -f ./docker-compose-associated-service.yml up -d` inside the folder to start the compose services configs, and simply `docker compose -f ./docker-compose-associated-service.yml down` to stop the services.

**Important:** Please replace `associated-service` with the appropriate service name.

The currents Pi-Hole examples currently includes:

- [Pi-Hole + Caddy](./Caddy/)
- [Pi-Hole + Unbound](./Unbound/)

**Note:** The configurations examples are provided `as is`. Please refer to the [Docker Documentation](https://docs.docker.com/) & [Docker Compose Documentation](https://docs.docker.com/compose/)