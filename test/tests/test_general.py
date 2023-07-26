import pytest


@pytest.mark.parametrize("test_args", ['-e "PIHOLE_UID=456"'])
def test_pihole_uid_env_var(docker):
    func = docker.run("id -u pihole")
    assert "456" in func.stdout


@pytest.mark.parametrize("test_args", ['-e "PIHOLE_GID=456"'])
def test_pihole_gid_env_var(docker):
    func = docker.run("id -g pihole")
    assert "456" in func.stdout
