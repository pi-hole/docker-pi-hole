.PHONY: help lint build

# Use bash for inline if-statements in arch_patch target
SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1
export COMPOSE_DOCKER_CLI_BUILD:=1


# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

lint: ## stop all containers
	@echo "lint dockerfile ..."
	docker image pull hadolint/hadolint
	docker run -i --rm hadolint/hadolint < Dockerfile

build: ## build image
	@echo -e "build image .."
	## docker-compose -f docker-compose-dev.yml build
	docker buildx build --load --progress plain --build-arg aptCacher="192.168.53.208" --build-arg NAME=edgd1er/pihole \
	--build-arg S6_OVERLAY_VERSION=3.0.0.2 --build-arg DEBIAN_VERSION=bullseye-slim --build-arg PIHOLE_DOCKER_TAG=latest \
	--build-arg PIHOLE_BASE=debian:bullseye-slim --build-arg PH_VERBOSE=1 -f Dockerfile -t edgd1er/pihole:dev .

up:
	@echo "run container"
	docker-compose up

upbuild:
	docker compose up --build