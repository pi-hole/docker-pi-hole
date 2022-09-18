import pytest
import time

""" conftest.py provides the defaults through fixtures """
""" Note, testinfra builtins don't seem fully compatible with
        docker containers (esp. musl based OSs) stripped down nature """


# If the test runs /usr/local/bin/_startup.sh, do not let s6 run it too!  Kill entrypoint to avoid race condition/duplicated execution
@pytest.mark.parametrize("entrypoint,cmd", [("--entrypoint=tail", "-f /dev/null")])
@pytest.mark.parametrize(
    "args,error_msg,expect_rc",
    [
        (
            '-e FTLCONF_LOCAL_IPV4="1.2.3.z"',
            "FTLCONF_LOCAL_IPV4 Environment variable (1.2.3.z) doesn't appear to be a valid IPv4 address",
            1,
        ),
        (
            '-e FTLCONF_LOCAL_IPV4="1.2.3.4" -e FTLCONF_LOCAL_IPV6="1234:1234:1234:ZZZZ"',
            "Environment variable (1234:1234:1234:ZZZZ) doesn't appear to be a valid IPv6 address",
            1,
        ),
        (
            '-e FTLCONF_LOCAL_IPV4="1.2.3.4" -e FTLCONF_LOCAL_IPV6="kernel"',
            "ERROR: You passed in IPv6 with a value of 'kernel'",
            1,
        ),
    ],
)
def test_ftlconf_local_addr_invalid_ips_triggers_exit_error(
    docker, error_msg, expect_rc
):
    start = docker.run("/usr/local/bin/_startup.sh")
    assert start.rc == expect_rc
    assert "ERROR" in start.stdout
    assert error_msg in start.stdout
