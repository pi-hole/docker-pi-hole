import os
import pytest
import re

CMD_APPLY_FTL_CONFIG_FROM_ENV = ". bash_functions.sh ; apply_FTL_Configs_From_Env"


@pytest.mark.parametrize("test_args", ['-e "FTLCONF_webserver.port=999"'])
def test_ftlconf_webserver_port(docker):
    func = docker.run(CMD_APPLY_FTL_CONFIG_FROM_ENV)
    assert "Applied pihole-FTL setting webserver.port=999" in func.stdout


@pytest.mark.parametrize(
    "test_args", ['-e "FTLCONF_dns.upstreams=1.1.1.1;8.8.8.8#1234"']
)
def test_ftlconf_dns_upstreams(docker):
    func = docker.run(CMD_APPLY_FTL_CONFIG_FROM_ENV)
    assert (
        'Applied pihole-FTL setting dns.upstreams=["1.1.1.1","8.8.8.8#1234"]'
        in func.stdout
    )
