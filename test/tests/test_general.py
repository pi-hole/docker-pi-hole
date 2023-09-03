import pytest


@pytest.mark.parametrize("test_args", ['-e "PIHOLE_UID=456"'])
def test_pihole_uid_env_var(docker):
    func = docker.run("id -u pihole")
    assert "456" in func.stdout


@pytest.mark.parametrize("test_args", ['-e "PIHOLE_GID=456"'])
def test_pihole_gid_env_var(docker):
    func = docker.run("id -g pihole")
    assert "456" in func.stdout


# We immediately remove the adlists.list file so that gravity does not attempt to download a default list
# Wait 5 seconds for gravity to finish, then kill the start.sh script
# Finally, tail the FTL log to see if it shuts down cleanly
@pytest.mark.parametrize("test_args", ['-e "PH_VERBOSE=1"'])
def test_pihole_ftl_clean_shutdown(docker):
    func = docker.run(
        """
        sleep 5
        killall --signal 15 start.sh
        sleep 5
        tail -f /var/log/pihole-FTL.log
    """
    )
    assert "INFO: Shutting down... // exit code 0 // jmpret 0" in func.stdout
    assert "INFO: ########## FTL terminated after" in func.stdout
