import os
import pytest
import re

SETUPVARS_LOC = "/etc/pihole/setupVars.conf"
DNSMASQ_CONFIG_LOC = "/etc/dnsmasq.d/01-pihole.conf"
CMD_SETUP_FTL_CACHESIZE = ". bash_functions.sh ; setup_FTL_CacheSize"
CMD_SETUP_FTL_INTERFACE = ". bash_functions.sh ; setup_FTL_Interface"
CMD_SETUP_WEB_PASSWORD = ". bash_functions.sh ; setup_web_password"


def _cat(file):
    return "cat {}".format(file)


def _grep(string, file):
    return "grep -q '{}' {}".format(string, file)


@pytest.mark.parametrize(
    "test_args,expected_ipv6,expected_stdout",
    [
        ("", True, "IPv4 and IPv6"),
        ('-e "IPv6=True"', True, "IPv4 and IPv6"),
        ('-e "IPv6=False"', False, "IPv4"),
        ('-e "IPv6=foobar"', False, "IPv4"),
    ],
)
def test_ipv6_not_true_removes_ipv6(
    docker, slow, test_args, expected_ipv6, expected_stdout
):
    """When a user overrides IPv6=True they only get IPv4 listening webservers"""
    IPV6_LINE = "use-ipv6.pl"
    WEB_CONFIG = "/etc/lighttpd/lighttpd.conf"

    function = docker.run(". /usr/local/bin/bash_functions.sh ; setup_ipv4_ipv6")
    assert "Using {}".format(expected_stdout) in function.stdout
    if expected_stdout == "IPv4":
        assert "IPv6" not in function.stdout
    # On overlay2(?) docker sometimes writes to disk are slow enough to break some tests...
    expected_ipv6_check = (
        lambda: (
            IPV6_LINE in docker.run("grep 'use-ipv6.pl' {}".format(WEB_CONFIG)).stdout
        )
        == expected_ipv6
    )
    slow(expected_ipv6_check)


@pytest.mark.parametrize("test_args", ['-e "WEB_PORT=999"'])
def test_overrides_default_web_port(docker, slow, test_args):
    """When a --net=host user sets WEB_PORT to avoid synology's 80 default IPv4 and or IPv6 ports are updated"""
    CONFIG_LINE = r"server.port\s*=\s*999"
    WEB_CONFIG = "/etc/lighttpd/lighttpd.conf"

    function = docker.run(
        ". /usr/local/bin/bash_functions.sh ; eval `grep setup_web_port /usr/local/bin/_startup.sh`"
    )
    assert "  [i] Custom WEB_PORT set to 999" in function.stdout
    assert (
        "  [i] Without proper router DNAT forwarding to 127.0.0.1:999, you may not get any blocked websites on ads"
        in function.stdout
    )
    slow(
        lambda: re.search(CONFIG_LINE, docker.run(_cat(WEB_CONFIG)).stdout) is not None
    )


@pytest.mark.parametrize(
    "test_args,expected_error",
    [
        (
            '-e WEB_PORT="LXXX"',
            "WARNING: Custom WEB_PORT not used - LXXX is not an integer",
        ),
        (
            '-e WEB_PORT="1,000"',
            "WARNING: Custom WEB_PORT not used - 1,000 is not an integer",
        ),
        (
            '-e WEB_PORT="99999"',
            "WARNING: Custom WEB_PORT not used - 99999 is not within valid port range of 1-65535",
        ),
    ],
)
def test_bad_input_to_web_port(docker, test_args, expected_error):
    function = docker.run(
        ". /usr/local/bin/bash_functions.sh ; eval `grep setup_web_port /usr/local/bin/_startup.sh`"
    )
    assert expected_error in function.stdout


@pytest.mark.parametrize(
    "test_args,cache_size",
    [('-e CUSTOM_CACHE_SIZE="0"', "0"), ('-e CUSTOM_CACHE_SIZE="20000"', "20000")],
)
def test_overrides_default_custom_cache_size(docker, slow, test_args, cache_size):
    """Changes the cache_size setting to increase or decrease the cache size for dnsmasq"""
    CONFIG_LINE = r"cache-size\s*=\s*{}".format(cache_size)

    function = docker.run(
        "echo ${CUSTOM_CACHE_SIZE};. ./usr/local/bin/bash_functions.sh; echo ${CUSTOM_CACHE_SIZE}; eval `grep setup_FTL_CacheSize /usr/local/bin/_startup.sh`"
    )
    assert "Custom CUSTOM_CACHE_SIZE set to {}".format(cache_size) in function.stdout
    slow(
        lambda: re.search(CONFIG_LINE, docker.run(_cat(DNSMASQ_CONFIG_LOC)).stdout)
        is not None
    )


@pytest.mark.parametrize(
    "test_args",
    [
        '-e CUSTOM_CACHE_SIZE="-1"',
        '-e CUSTOM_CACHE_SIZE="1,000"',
    ],
)
def test_bad_input_to_custom_cache_size(docker, slow, test_args):
    CONFIG_LINE = r"cache-size\s*=\s*10000"

    docker.run(CMD_SETUP_FTL_CACHESIZE)
    slow(
        lambda: re.search(CONFIG_LINE, docker.run(_cat(DNSMASQ_CONFIG_LOC)).stdout)
        is not None
    )


@pytest.mark.parametrize(
    "test_args",
    [
        '-e DNSSEC="true" -e CUSTOM_CACHE_SIZE="0"',
    ],
)
def test_dnssec_enabled_with_custom_cache_size(docker, slow, test_args):
    CONFIG_LINE = r"cache-size\s*=\s*10000"

    docker.run(CMD_SETUP_FTL_CACHESIZE)
    slow(
        lambda: re.search(CONFIG_LINE, docker.run(_cat(DNSMASQ_CONFIG_LOC)).stdout)
        is not None
    )


@pytest.mark.parametrize(
    "args_env, expected_stdout, expected_config_line",
    [
        ("", "binding to default interface: eth0", "PIHOLE_INTERFACE=eth0"),
        (
            '-e INTERFACE="br0"',
            "binding to custom interface: br0",
            "PIHOLE_INTERFACE=br0",
        ),
    ],
)
def test_dns_interface_override_defaults(
    docker, slow, args_env, expected_stdout, expected_config_line
):
    """When INTERFACE environment var is passed in, overwrite dnsmasq interface"""
    function = docker.run(CMD_SETUP_FTL_INTERFACE)
    assert expected_stdout in function.stdout
    slow(
        lambda: expected_config_line + "\n"
        == docker.run('grep "^PIHOLE_INTERFACE" {}'.format(SETUPVARS_LOC)).stdout
    )


expected_debian_lines = [
    '"VIRTUAL_HOST" => "127.0.0.1"',
    '"PHP_ERROR_LOG" => "/var/log/lighttpd/error-pihole.log"',
]


@pytest.mark.parametrize(
    "expected_lines,repeat_function",
    [(expected_debian_lines, 1), (expected_debian_lines, 2)],
)
def test_debian_setup_php_env(docker, expected_lines, repeat_function):
    """confirm all expected output is there and nothing else"""
    for _ in range(repeat_function):
        docker.run(
            ". /usr/local/bin/bash_functions.sh ; eval `grep setup_php_env /usr/local/bin/_startup.sh`"
        )
    for expected_line in expected_lines:
        search_config_cmd = (
            "grep -c '{}' /etc/lighttpd/conf-enabled/15-fastcgi-php.conf".format(
                expected_line
            )
        )
        search_config_count = docker.run(search_config_cmd)
        found_lines = int(search_config_count.stdout.rstrip("\n"))
        if found_lines > 1:
            assert (
                False
            ), f"Found line {expected_line} times (more than once): {found_lines}"


def test_webpassword_random_generation(docker):
    """When a user sets webPassword env the admin password gets set to that"""
    function = docker.run(CMD_SETUP_WEB_PASSWORD)
    assert "assigning random password" in function.stdout.lower()


@pytest.mark.parametrize("entrypoint,cmd", [("--entrypoint=tail", "-f /dev/null")])
@pytest.mark.parametrize(
    "args_env,secure,setupvars_hash",
    [
        (
            "-e WEBPASSWORD=login",
            True,
            "WEBPASSWORD=6060d59351e8c2f48140f01b2c3f3b61652f396c53a5300ae239ebfbe7d5ff08",
        ),
        ('-e WEBPASSWORD=""', False, ""),
    ],
)
def test_webpassword_env_assigns_password_to_file_or_removes_if_empty(
    docker, args_env, secure, setupvars_hash
):
    """When a user sets webPassword env the admin password gets set or removed if empty"""
    function = docker.run(CMD_SETUP_WEB_PASSWORD)

    if secure:
        assert "new password set" in function.stdout.lower()
        assert docker.run(_grep(setupvars_hash, SETUPVARS_LOC)).rc == 0
    else:
        assert "password removed" in function.stdout.lower()
        assert docker.run(_grep("^WEBPASSWORD=$", SETUPVARS_LOC)).rc == 0


@pytest.mark.parametrize("entrypoint,cmd", [("--entrypoint=tail", "-f /dev/null")])
@pytest.mark.parametrize("test_args", ["-e WEBPASSWORD=login", '-e WEBPASSWORD=""'])
def test_env_always_updates_password(docker, args_env, test_args):
    """When a user sets the WEBPASSWORD environment variable, ensure it always sets the password"""
    function = docker.run(CMD_SETUP_WEB_PASSWORD)

    assert "  [i] Assigning password defined by Environment Variable" in function.stdout


@pytest.mark.parametrize("entrypoint,cmd", [("--entrypoint=tail", "-f /dev/null")])
def test_setupvars_trumps_random_password_if_set(docker, args_env, test_args):
    """If a password is already set in setupvars, and no password is set in the environment variable, do not generate a random password"""
    docker.run(
        ". /opt/pihole/utils.sh ; addOrEditKeyValPair {} WEBPASSWORD volumepass".format(
            SETUPVARS_LOC
        )
    )
    function = docker.run(CMD_SETUP_WEB_PASSWORD)

    assert "Pre existing WEBPASSWORD found" in function.stdout
    assert docker.run(_grep("WEBPASSWORD=volumepass", SETUPVARS_LOC)).rc == 0
