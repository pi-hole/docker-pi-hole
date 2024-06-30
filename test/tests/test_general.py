import pytest


@pytest.mark.parametrize("test_args", ['-e "PIHOLE_UID=456"'])
def test_pihole_uid_env_var(docker):
    func = docker.run("id -u pihole")
    assert "456" in func.stdout


@pytest.mark.parametrize("test_args", ['-e "PIHOLE_GID=456"'])
def test_pihole_gid_env_var(docker):
    func = docker.run("id -g pihole")
    assert "456" in func.stdout


# Wait 5 seconds for startup, then kill the start.sh script
# Finally, grep the FTL log to see if it has been shut down cleanly
def test_pihole_ftl_clean_shutdown(docker):
    func = docker.run(
        """
        sleep 5
        killall --signal 15 start.sh
        sleep 5
        grep 'jmpret\|terminated' /var/log/pihole/FTL.log
    """
    )
    assert "INFO: Shutting down... // exit code 0 // jmpret 0" in func.stdout
    assert "INFO: ########## FTL terminated after" in func.stdout
