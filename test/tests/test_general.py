import pytest
import os


# Adding 5 seconds sleep to give the emulated architecture time to run
@pytest.mark.parametrize("docker", ["PIHOLE_UID=456"], indirect=True)
def test_pihole_uid_env_var(docker):
    func = docker.run("echo ${PIHOLE_UID}")
    assert "456" in func.stdout
    func = docker.run(
        """
        sleep 5
        id -u pihole
        """
    )
    assert "456" in func.stdout


# Adding 5 seconds sleep to give the emulated architecture time to run
@pytest.mark.parametrize("docker", ["PIHOLE_GID=456"], indirect=True)
def test_pihole_gid_env_var(docker):
    func = docker.run("echo ${PIHOLE_GID}")
    assert "456" in func.stdout
    func = docker.run(
        """
        sleep 5
        id -g pihole
        """
    )
    assert "456" in func.stdout


def test_pihole_ftl_version(docker):
    func = docker.run("pihole-FTL -vv")
    assert func.rc == 0
    assert "Version:" in func.stdout


@pytest.mark.skipif(
    not os.environ.get("CIPLATFORM"),
    reason="CIPLATFORM environment variable not set, running locally",
)
def test_pihole_ftl_architecture(docker):
    func = docker.run("pihole-FTL -vv")
    assert func.rc == 0
    assert "Architecture:" in func.stdout
    # Get the expected architecture from CIPLATFORM environment variable
    platform = os.environ.get("CIPLATFORM")
    assert platform in func.stdout


# Wait for FTL to start up, then stop the container gracefully
# Finally, check the container logs to see if FTL was shut down cleanly
def test_pihole_ftl_starts_and_shuts_down_cleanly(docker):
    import subprocess
    import time

    # Get the container ID from the docker fixture
    container_id = docker.backend.name

    # Wait for FTL to fully start up by checking logs
    max_wait_time = 60  # Maximum wait time in seconds
    start_time = time.time()
    ftl_started = False

    while time.time() - start_time < max_wait_time:
        result = subprocess.run(
            ["docker", "logs", container_id], capture_output=True, text=True
        )

        if "########## FTL started" in result.stdout:
            ftl_started = True
            break

        time.sleep(1)  # Check every second

    assert ftl_started, f"FTL did not start within {max_wait_time} seconds"

    # Stop the container gracefully (sends SIGTERM)
    subprocess.run(["docker", "stop", container_id], check=True)

    # Get the container logs
    result = subprocess.run(
        ["docker", "logs", container_id], capture_output=True, text=True
    )

    # Check for clean shutdown messages in the logs
    assert "INFO: ########## FTL terminated after" in result.stdout
    assert "(code 0)" in result.stdout


def test_cronfile_valid(docker):
    func = docker.run(
        """
        /usr/bin/crontab /crontab.txt
        crond -d 8 -L /cron.log
        grep 'parse error' /cron.log
    """
    )
    assert "parse error" not in func.stdout
