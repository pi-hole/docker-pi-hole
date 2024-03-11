import pytest


@pytest.mark.parametrize("test_args", ['-e "FTLCONF_webserver_port=999"'])
def test_ftlconf_webserver_port(docker):
    func = docker.run("pihole-FTL --config webserver.port")
    assert "999" in func.stdout


@pytest.mark.parametrize(
    "test_args", ['-e "FTLCONF_dns_upstreams=1.2.3.4;5.6.7.8#1234"']
)
def test_ftlconf_dns_upstreams(docker):
    func = docker.run("pihole-FTL --config dns.upstreams")
    assert "[ 1.2.3.4, 5.6.7.8#1234 ]" in func.stdout


CMD_SETUP_WEB_PASSWORD = ". bash_functions.sh ; setup_web_password"


def test_random_password_assigned_fresh_start(docker):
    func = docker.run(CMD_SETUP_WEB_PASSWORD)
    assert "assigning random password:" in func.stdout


@pytest.mark.parametrize(
    "test_args", ['-e "FTLCONF_webserver_api_password=1234567890"']
)
def test_password_set_by_envvar(docker):
    func = docker.run(CMD_SETUP_WEB_PASSWORD)
    assert "Assigning password defined by Environment Variable" in func.stdout
