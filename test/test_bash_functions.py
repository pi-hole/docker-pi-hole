import pytest
import re

DEFAULTARGS = '-e ServerIP="127.0.0.1" '

@pytest.mark.parametrize('args,expected_ipv6,expected_stdout', [
    (DEFAULTARGS, True, 'IPv4 and IPv6'),
    (DEFAULTARGS + '-e "IPv6=True"', True, 'IPv4 and IPv6'),
    (DEFAULTARGS + '-e "IPv6=False"', False, 'IPv4'),
    (DEFAULTARGS + '-e "IPv6=foobar"', False, 'IPv4'),
])
def test_IPv6_not_True_removes_ipv6(Docker, tag, args, expected_ipv6, expected_stdout):
    ''' When a user overrides IPv6=True they only get IPv4 listening webservers '''
    IPV6_LINE = { 'alpine': 'listen [::]:80 default_server',
                  'debian': 'use-ipv6.pl' }
    WEB_CONFIG = { 'alpine': '/etc/nginx/nginx.conf',
                   'debian': '/etc/lighttpd/lighttpd.conf' }

    function = Docker.run('. /bash_functions.sh ; setup_ipv4_ipv6')
    assert "Using {}".format(expected_stdout) in function.stdout
    config = Docker.run('cat {}'.format( WEB_CONFIG[tag])).stdout
    assert (IPV6_LINE[tag] in config) == expected_ipv6

@pytest.mark.parametrize('args, expected_stdout, dns1, dns2', [
    ('-e ServerIP="1.2.3.4"', 'default DNS', '8.8.8.8', '8.8.4.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4"', 'custom DNS', '1.2.3.4', '8.8.4.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS2="1.2.3.4"', 'custom DNS', '8.8.8.8', '1.2.3.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4" -e DNS2="2.2.3.4"', 'custom DNS', '1.2.3.4', '2.2.3.4' ),
])
def test_DNS_Envs_override_defaults(Docker, args, expected_stdout, dns1, dns2):
    ''' When DNS environment vars are passed in, they override default dns servers '''
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_dnsmasq /start.sh`')
    assert expected_stdout in function.stdout

    docker_dns_servers = Docker.run('grep "^server=" /etc/dnsmasq.d/01-pihole.conf').stdout
    expected_servers = 'server={}\nserver={}\n'.format(dns1, dns2)
    assert expected_servers == docker_dns_servers

@pytest.mark.parametrize('args, expected_stdout, expected_config_line', [
    ('-e ServerIP="1.2.3.4"', 'binding to default interface: eth0', 'interface=eth0' ),
    ('-e ServerIP="1.2.3.4" -e INTERFACE="eth0"', 'binding to default interface: eth0', 'interface=eth0' ),
    ('-e ServerIP="1.2.3.4" -e INTERFACE="br0"', 'binding to custom interface: br0', 'interface=br0'),
])
def test_DNS_interface_override_defaults(Docker, args, expected_stdout, expected_config_line):
    ''' When INTERFACE environment var is passed in, overwrite dnsmasq interface '''
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_dnsmasq /start.sh`')
    assert expected_stdout in function.stdout

    docker_dns_interface = Docker.run('grep "^interface" /etc/dnsmasq.d/01-pihole.conf').stdout
    assert expected_config_line + '\n' == docker_dns_interface

expected_debian_lines = [
    '"VIRTUAL_HOST" => "127.0.0.1"',
    '"ServerIP" => "127.0.0.1"',
    '"PHP_ERROR_LOG" => "/var/log/lighttpd/error.log"'
]
@pytest.mark.parametrize('tag,expected_lines,repeat_function', [
    ('debian', expected_debian_lines, 1),
    ('debian', expected_debian_lines, 2)
])
def test_debian_setup_php_env(Docker, tag, expected_lines, repeat_function):
    ''' confirm all expected output is there and nothing else '''
    stdout = ''
    for i in range(repeat_function):
        stdout = Docker.run('. /bash_functions.sh ; eval `grep setup_php_env /start.sh`').stdout
    for expected_line in expected_lines:
        search_config_cmd = "grep -c '{}' /etc/lighttpd/conf-enabled/15-fastcgi-php.conf".format(expected_line)
        search_config_count = Docker.run(search_config_cmd)
        assert search_config_count.stdout.rstrip('\n') == '1'

@pytest.mark.parametrize('args,secure,setupVarsHash', [
    ('-e ServerIP=1.2.3.4 -e WEBPASSWORD=login', True, 'WEBPASSWORD=6060d59351e8c2f48140f01b2c3f3b61652f396c53a5300ae239ebfbe7d5ff08'),
    ('-e ServerIP=1.2.3.4 -e WEBPASSWORD=""', False, ''),
    ('-e ServerIP=1.2.3.4', True, 'WEBPASSWORD='),
])
def test_webPassword_env_assigns_password_to_file(Docker, args, secure, setupVarsHash):
    ''' When a user sets webPassword env the admin password gets set to that '''
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_password /start.sh`')
    if secure and 'WEBPASSWORD' not in args:
        assert 'assigning random password' in function.stdout.lower()
    else:
        assert 'assigning random password' not in function.stdout.lower()

    if secure:
        assert 'new password set' in function.stdout.lower()
        assert Docker.run('grep -q \'{}\' {}'.format(setupVarsHash, '/etc/pihole/setupVars.conf')).rc == 0
    else:
        assert 'password removed' in function.stdout.lower()
        assert Docker.run('grep -q \'^WEBPASSWORD=$\' /etc/pihole/setupVars.conf').rc == 0
