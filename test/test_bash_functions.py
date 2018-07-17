import pytest
import re

DEFAULTARGS = '-e ServerIP="127.0.0.1" '

@pytest.mark.parametrize('args,expected_ipv6,expected_stdout', [
    (DEFAULTARGS, True, 'IPv4 and IPv6'),
    (DEFAULTARGS + '-e "IPv6=True"', True, 'IPv4 and IPv6'),
    (DEFAULTARGS + '-e "IPv6=False"', False, 'IPv4'),
    (DEFAULTARGS + '-e "IPv6=foobar"', False, 'IPv4'),
])
def test_IPv6_not_True_removes_ipv6(Docker, os, args, expected_ipv6, expected_stdout):
    ''' When a user overrides IPv6=True they only get IPv4 listening webservers '''
    IPV6_LINE = { 'debian': 'use-ipv6.pl' }
    WEB_CONFIG = { 'debian': '/etc/lighttpd/lighttpd.conf' }

    function = Docker.run('. /bash_functions.sh ; setup_ipv4_ipv6')
    assert "Using {}".format(expected_stdout) in function.stdout
    config = Docker.run('cat {}'.format( WEB_CONFIG[os])).stdout
    assert (IPV6_LINE[os] in config) == expected_ipv6

@pytest.mark.parametrize('args', [DEFAULTARGS + '-e "WEB_PORT=999"'])
def test_overrides_default_WEB_PORT(Docker, os, args):
    ''' When a --net=host user sets WEB_PORT to avoid synology's 80 default IPv4 and or IPv6 ports are updated'''
    CONFIG_LINES = { 'debian': ['server.port\s*=\s*999'] }
    WEB_CONFIG = { 'debian': '/etc/lighttpd/lighttpd.conf' }

    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_port /start.sh`')
    assert "Custom WEB_PORT set to 999" in function.stdout
    assert "INFO: Without proper router DNAT forwarding to 127.0.0.1:999, you may not get any blocked websites on ads" in function.stdout
    config = Docker.run('cat {}'.format( WEB_CONFIG[os])).stdout
    for expected_line in CONFIG_LINES[os]:
        assert re.search(expected_line, config) != None
    # grep fails to find any of the old address w/o port
    assert Docker.run('grep -rq "://127.0.0.1/" /var/www/html/').rc == 1
    assert Docker.run('grep -rq "://pi.hole/" /var/www/html/').rc == 1
    # Find at least one instance of our changes 
    # upstream repos determines how many and I don't want to keep updating this test
    assert int(Docker.run('grep -rl "://127.0.0.1:999/" /var/www/html/ | wc -l').stdout) >= 1
    assert int(Docker.run('grep -rl "://pi.hole:999/" /var/www/html/ | wc -l').stdout) >= 1

@pytest.mark.parametrize('args,expected_error', [
    (DEFAULTARGS + '-e WEB_PORT="LXXX"', 'WARNING: Custom WEB_PORT not used - LXXX is not an integer'),
    (DEFAULTARGS + '-e WEB_PORT="1,000"', 'WARNING: Custom WEB_PORT not used - 1,000 is not an integer'),
    (DEFAULTARGS + '-e WEB_PORT="99999"', 'WARNING: Custom WEB_PORT not used - 99999 is not within valid port range of 1-65535'),
])
def test_bad_input_to_WEB_PORT(Docker, args, expected_error):
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_port /start.sh`')
    assert expected_error in function.stdout


# DNS Environment Variable behavior in combinations of modified pihole LTE settings
@pytest.mark.parametrize('args, expected_stdout, dns1, dns2', [
    ('-e ServerIP="1.2.3.4"',                                     'default DNS', '8.8.8.8', '8.8.4.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4"',                   'custom DNS',  '1.2.3.4', '8.8.4.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS2="1.2.3.4"',                   'custom DNS',  '8.8.8.8', '1.2.3.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4" -e DNS2="2.2.3.4"', 'custom DNS',  '1.2.3.4', '2.2.3.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4" -e DNS2="no"', 'custom DNS',  '1.2.3.4', None ),
    ('-e ServerIP="1.2.3.4" -e DNS2="no"', 'custom DNS',  '8.8.8.8', None ),
])
def test_override_default_servers_with_DNS_EnvVars(Docker, args, expected_stdout, dns1, dns2):
    ''' on first boot when DNS vars are NOT set explain default google DNS settings are used
                   or when DNS vars are set override the pihole DNS settings '''
    assert Docker.run('test -f /.piholeFirstBoot').rc == 0
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_dnsmasq /start.sh`')
    assert expected_stdout in function.stdout

    docker_dns_servers = Docker.run('grep "^server=" /etc/dnsmasq.d/01-pihole.conf').stdout
    expected_servers = 'server={}\n'.format(dns1) if dns2 == None else 'server={}\nserver={}\n'.format(dns1, dns2)
    assert expected_servers == docker_dns_servers

@pytest.mark.parametrize('args, dns1, dns2, expected_stdout', [
    ('-e ServerIP="1.2.3.4"', '9.9.9.1', '9.9.9.2',
     'Existing DNS servers used'),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4"', '9.9.9.1', '9.9.9.2',
     'Docker DNS variables not used\nExisting DNS servers used'),
    ('-e ServerIP="1.2.3.4" -e DNS2="1.2.3.4"', '8.8.8.8', '1.2.3.4',
     'Docker DNS variables not used\nExisting DNS servers used'),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4" -e DNS2="2.2.3.4"', '1.2.3.4', '2.2.3.4',
     'Docker DNS variables not used\nExisting DNS servers used'),
])
def test_DNS_Envs_are_secondary_to_setupvars(Docker, args, expected_stdout, dns1, dns2):
    ''' on second boot when DNS vars are set just use pihole DNS settings
                    or when DNS vars and FORCE_DNS var are set override the pihole DNS settings '''
    # Given we are not booting for the first time
    assert Docker.run('rm /.piholeFirstBoot').rc == 0

    # and a user already has custom pihole dns variables in setup vars
    setupVars = '/etc/pihole/setupVars.conf'
    Docker.run('sed -i "/^PIHOLE_DNS_1/ c\PIHOLE_DNS_1={}" {}'.format(dns1, setupVars))
    Docker.run('sed -i "/^PIHOLE_DNS_2/ c\PIHOLE_DNS_2={}" {}'.format(dns2, setupVars))

    # When we run setup dnsmasq during startup of the container
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_dnsmasq /start.sh`')
    assert expected_stdout in function.stdout

    expected_servers = 'server={}\nserver={}\n'.format(dns1, dns2)
    servers = Docker.run('grep "^server=" /etc/dnsmasq.d/01-pihole.conf').stdout
    searchDns1 = servers.split('\n')[0]
    searchDns2 = servers.split('\n')[1]

    # Then the servers are still what the user had customized if forced dnsmasq is not set
    assert 'server={}'.format(dns1) == searchDns1
    assert 'server={}'.format(dns2) == searchDns2

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
@pytest.mark.parametrize('os,expected_lines,repeat_function', [
    ('debian', expected_debian_lines, 1),
    ('debian', expected_debian_lines, 2)
])
def test_debian_setup_php_env(Docker, os, expected_lines, repeat_function):
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
