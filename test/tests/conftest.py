import pytest
import subprocess
import testinfra
import testinfra.backend.docker
import os


# Monkeypatch sh to bash, if they ever support non hard code /bin/sh this can go away
# https://github.com/pytest-dev/pytest-testinfra/blob/master/testinfra/backend/docker.py
def run_bash(self, command, *args, **kwargs):
    cmd = self.get_command(command, *args)
    if self.user is not None:
        out = self.run_local(
            "docker exec -u %s %s /bin/bash -c %s", self.user, self.name, cmd
        )
    else:
        out = self.run_local("docker exec %s /bin/bash -c %s", self.name, cmd)
    out.command = self.encode(cmd)
    return out


testinfra.backend.docker.DockerBackend.run = run_bash


# scope='session' uses the same container for all the tests;
# scope='function' uses a new container per test function.
@pytest.fixture(scope="function")
def docker(request):
    # Get platform from environment variable, default to None if not set
    platform = os.environ.get("CIPLATFORM")

    # build the docker run command with args
    cmd = ["docker", "run", "-d", "-t"]

    # Only add platform flag if CIPLATFORM is set
    if platform:
        cmd.extend(["--platform", platform])

    # Get env vars from parameterization
    env_vars = getattr(request, "param", [])
    if isinstance(env_vars, str):
        env_vars = [env_vars]

    # add parameterized environment variables
    for env_var in env_vars:
        cmd.extend(["-e", env_var])

    # ensure PYTEST=1 is set
    if not any("PYTEST=1" in arg for arg in cmd):
        cmd.extend(["-e", "PYTEST=1"])

    # add default TZ if not already set
    if not any("TZ=" in arg for arg in cmd):
        cmd.extend(["-e", 'TZ="Europe/London"'])

    # add the image name
    cmd.append("pihole:CI_container")

    # run a container
    docker_id = subprocess.check_output(cmd).decode().strip()
    # return a testinfra connection to the container
    yield testinfra.get_host("docker://" + docker_id)
    # at the end of the test suite, destroy the container
    subprocess.check_call(["docker", "rm", "-f", docker_id])
