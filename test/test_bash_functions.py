import os
import pytest
import re


@pytest.mark.parametrize('test_args,expected_ipv6,expected_stdout', [
    ('', True, 'IPv4 and IPv6'),
    ('-e "IPv6=True"', True, 'IPv4 and IPv6'),
    ('-e "IPv6=False"', False, 'IPv4'),
    ('-e "IPv6=foobar"', False, 'IPv4'),
])
def test_IPv6_not_True_removes_ipv6(Docker, Slow, test_args, expected_ipv6, expected_stdout):
    ''' When a user overrides IPv6=True they only get IPv4 listening webservers '''
    IPV6_LINE = 'use-ipv6.pl'
    WEB_CONFIG = '/etc/lighttpd/lighttpd.conf'

    function = Docker.run('. /bash_functions.sh ; setup_ipv4_ipv6')
    assert "Using {}".format(expected_stdout) in function.stdout
    if expected_stdout == 'IPv4':
        assert 'IPv6' not in function.stdout
    # On overlay2(?) docker sometimes writes to disk are slow enough to break some tests...
    expected_ipv6_check = lambda: (\
        IPV6_LINE in Docker.run('grep \'use-ipv6.pl\' {}'.format(WEB_CONFIG)).stdout
    ) == expected_ipv6
    Slow(expected_ipv6_check)


@pytest.mark.parametrize('test_args', ['-e "WEB_PORT=999"'])
def test_overrides_default_WEB_PORT(Docker, Slow, test_args):
    ''' When a --net=host user sets WEB_PORT to avoid synology's 80 default IPv4 and or IPv6 ports are updated'''
    CONFIG_LINE = 'server.port\s*=\s*999'
    WEB_CONFIG = '/etc/lighttpd/lighttpd.conf'

    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_port /start.sh`')
    assert "Custom WEB_PORT set to 999" in function.stdout
    assert "INFO: Without proper router DNAT forwarding to 127.0.0.1:999, you may not get any blocked websites on ads" in function.stdout
    Slow(lambda: re.search(CONFIG_LINE, Docker.run('cat {}'.format(WEB_CONFIG)).stdout) != None)
    # grep fails to find any of the old address w/o port
    assert Docker.run('grep -rq "://127.0.0.1/" /var/www/html/').rc == 1
    assert Docker.run('grep -rq "://pi.hole/" /var/www/html/').rc == 1
    # Find at least one instance of our changes 
    # upstream repos determines how many and I don't want to keep updating this test
    assert int(Docker.run('grep -rl "://127.0.0.1:999/" /var/www/html/ | wc -l').stdout) >= 1
    assert int(Docker.run('grep -rl "://pi.hole:999/" /var/www/html/ | wc -l').stdout) >= 1


@pytest.mark.parametrize('test_args,expected_error', [
    ('-e WEB_PORT="LXXX"', 'WARNING: Custom WEB_PORT not used - LXXX is not an integer'),
    ('-e WEB_PORT="1,000"', 'WARNING: Custom WEB_PORT not used - 1,000 is not an integer'),
    ('-e WEB_PORT="99999"', 'WARNING: Custom WEB_PORT not used - 99999 is not within valid port range of 1-65535'),
])
def test_bad_input_to_WEB_PORT(Docker, test_args, expected_error):
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_port /start.sh`')
    assert expected_error in function.stdout


# DNS Environment Variable behavior in combinations of modified pihole LTE settings
@pytest.mark.parametrize('args_env, expected_stdout, dns1, dns2', [
    ('',                                     'default DNS', '8.8.8.8', '8.8.4.4' ),
    ('-e DNS1="1.2.3.4"',                   'custom DNS',  '1.2.3.4', '8.8.4.4' ),
    ('-e DNS2="1.2.3.4"',                   'custom DNS',  '8.8.8.8', '1.2.3.4' ),
    ('-e DNS1="1.2.3.4" -e DNS2="2.2.3.4"', 'custom DNS',  '1.2.3.4', '2.2.3.4' ),
    ('-e DNS1="1.2.3.4" -e DNS2="no"',      'custom DNS',  '1.2.3.4', None ),
    ('-e DNS2="no"',                        'custom DNS',  '8.8.8.8', None ),
])
def test_override_default_servers_with_DNS_EnvVars(Docker, Slow, args_env, expected_stdout, dns1, dns2):
    ''' on first boot when DNS vars are NOT set explain default google DNS settings are used
                   or when DNS vars are set override the pihole DNS settings '''
    assert Docker.run('test -f /.piholeFirstBoot').rc == 0
    function = Docker.run('. /bash_functions.sh ; eval `grep "^setup_dnsmasq " /start.sh`')
    assert expected_stdout in function.stdout
    expected_servers = 'server={}\n'.format(dns1) if dns2 == None else 'server={}\nserver={}\n'.format(dns1, dns2)
    Slow(lambda: expected_servers == Docker.run('grep "^server=" /etc/dnsmasq.d/01-pihole.conf').stdout)


@pytest.mark.skipif(os.environ.get('TRAVIS') == 'true',
                    reason="Can't get setupVar setup to work on travis")
@pytest.mark.parametrize('args_env, dns1, dns2, expected_stdout', [

    ('', '9.9.9.1', '9.9.9.2',
     'Existing DNS servers used'),
    ('-e DNS1="1.2.3.4"', '9.9.9.1', '9.9.9.2',
     'Docker DNS variables not used\nExisting DNS servers used (9.9.9.1 & 9.9.9.2)'),
    ('-e DNS2="1.2.3.4"', '8.8.8.8', None,
     'Docker DNS variables not used\nExisting DNS servers used (8.8.8.8 & unset)'),
    ('-e DNS1="1.2.3.4" -e DNS2="2.2.3.4"', '1.2.3.4', '2.2.3.4',
     'Docker DNS variables not used\nExisting DNS servers used (1.2.3.4 & 2.2.3.4'),
])
def test_DNS_Envs_are_secondary_to_setupvars(Docker, Slow, args_env, expected_stdout, dns1, dns2):
    ''' on second boot when DNS vars are set just use pihole DNS settings
                    or when DNS vars and FORCE_DNS var are set override the pihole DNS settings '''
    # Given we are not booting for the first time
    assert Docker.run('rm /.piholeFirstBoot').rc == 0

    # and a user already has custom pihole dns variables in setup vars
    dns_count = 1
    setupVars = '/etc/pihole/setupVars.conf'
    Docker.run('sed -i "/^PIHOLE_DNS/ d" {}'.format(setupVars))
    Docker.run('echo "PIHOLE_DNS_1={}" | tee -a {}'.format(dns1, setupVars))
    if dns2:
        Docker.run('echo "PIHOLE_DNS_2={}" | tee -a {}'.format(dns2, setupVars))
    Docker.run('sync {}'.format(setupVars))
    Slow(lambda: 'PIHOLE_DNS' in Docker.run('cat {}'.format(setupVars)).stdout)

    # When we run setup dnsmasq during startup of the container
    function = Docker.run('. /bash_functions.sh ; eval `grep "^setup_dnsmasq " /start.sh`')
    assert expected_stdout in function.stdout

    # Then the servers are still what the user had customized if forced dnsmasq is not set
    expected_servers = ['server={}'.format(dns1)]
    if dns2:
        expected_servers.append('server={}'.format(dns2))
    Slow(lambda: Docker.run('grep "^server=" /etc/dnsmasq.d/01-pihole.conf').stdout.strip().split('\n') == \
         expected_servers)


@pytest.mark.parametrize('args_env, expected_stdout, expected_config_line', [
    ('', 'binding to default interface: eth0', 'interface=eth0' ),
    ('-e INTERFACE="eth0"', 'binding to default interface: eth0', 'interface=eth0' ),
    ('-e INTERFACE="br0"', 'binding to custom interface: br0', 'interface=br0'),
])
def test_DNS_interface_override_defaults(Docker, Slow, args_env, expected_stdout, expected_config_line):
    ''' When INTERFACE environment var is passed in, overwrite dnsmasq interface '''
    function = Docker.run('. /bash_functions.sh ; eval `grep "^setup_dnsmasq " /start.sh`')
    assert expected_stdout in function.stdout
    Slow(lambda: expected_config_line + '\n' == Docker.run('grep "^interface" /etc/dnsmasq.d/01-pihole.conf').stdout)


expected_debian_lines = [
    '"VIRTUAL_HOST" => "127.0.0.1"',
    '"ServerIP" => "127.0.0.1"',
    '"PHP_ERROR_LOG" => "/var/log/lighttpd/error.log"'
]


@pytest.mark.parametrize('expected_lines,repeat_function', [
    (expected_debian_lines, 1),
    (expected_debian_lines, 2)
])
def test_debian_setup_php_env(Docker, expected_lines, repeat_function):
    ''' confirm all expected output is there and nothing else '''
    stdout = ''
    for i in range(repeat_function):
        stdout = Docker.run('. /bash_functions.sh ; eval `grep setup_php_env /start.sh`').stdout
    for expected_line in expected_lines:
        search_config_cmd = "grep -c '{}' /etc/lighttpd/conf-enabled/15-fastcgi-php.conf".format(expected_line)
        search_config_count = Docker.run(search_config_cmd)
        found_lines = int(search_config_count.stdout.rstrip('\n'))
        if found_lines > 1:
            assert False, "Found line {} times (more than once): {}".format(expected_line)


def test_webPassword_random_generation(Docker):
    ''' When a user sets webPassword env the admin password gets set to that '''
    function = Docker.run('. /bash_functions.sh ; eval `grep generate_password /start.sh`')
    assert 'assigning random password' in function.stdout.lower()


@pytest.mark.parametrize('entrypoint,cmd', [('--entrypoint=tail','-f /dev/null')])
@pytest.mark.parametrize('args_env,secure,setupVarsHash', [
    ('-e ServerIP=1.2.3.4 -e WEBPASSWORD=login', True, 'WEBPASSWORD=6060d59351e8c2f48140f01b2c3f3b61652f396c53a5300ae239ebfbe7d5ff08'),
    ('-e ServerIP=1.2.3.4 -e WEBPASSWORD=""', False, ''),
])
def test_webPassword_env_assigns_password_to_file_or_removes_if_empty(Docker, args_env, secure, setupVarsHash):
    ''' When a user sets webPassword env the admin password gets set or removed if empty '''
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_password /start.sh`')

    if secure:
        assert 'new password set' in function.stdout.lower()
        assert Docker.run('grep -q \'{}\' {}'.format(setupVarsHash, '/etc/pihole/setupVars.conf')).rc == 0
    else:
        assert 'password removed' in function.stdout.lower()
        assert Docker.run('grep -q \'^WEBPASSWORD=$\' /etc/pihole/setupVars.conf').rc == 0


@pytest.mark.parametrize('entrypoint,cmd', [('--entrypoint=tail','-f /dev/null')])
@pytest.mark.parametrize('test_args', ['-e WEBPASSWORD=login', '-e WEBPASSWORD=""'])
def test_webPassword_pre_existing_trumps_all_envs(Docker, args_env, test_args):
    '''When a user setup webPassword in the volume prior to first container boot,
        during prior container boot, the prior volume password is left intact / setup skipped'''
    Docker.run('. /opt/pihole/webpage.sh ; add_setting WEBPASSWORD volumepass')
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_web_password /start.sh`')

    assert '::: Pre existing WEBPASSWORD found' in function.stdout
    assert Docker.run('grep -q \'{}\' {}'.format('WEBPASSWORD=volumepass', '/etc/pihole/setupVars.conf')).rc == 0


@pytest.mark.parametrize('args_dns, expected_stdout', [
    # No DNS passed will vary by the host this is ran on, bad idea for a test
    #('', 'WARNING Misconfigured DNS in /etc/resolv.conf: Primary DNS should be 127.0.0.1'),
    ('--dns 1.1.1.1',                 'WARNING Misconfigured DNS in /etc/resolv.conf: Two DNS servers are recommended, 127.0.0.1 and any backup server\n'
                                      'WARNING Misconfigured DNS in /etc/resolv.conf: Primary DNS should be 127.0.0.1 (found 1.1.1.1)'),
    ('--dns 127.0.0.1',               'WARNING Misconfigured DNS in /etc/resolv.conf: Two DNS servers are recommended, 127.0.0.1 and any backup server'),
    ('--dns 1.1.1.1 --dns 127.0.0.1', 'WARNING Misconfigured DNS in /etc/resolv.conf: Primary DNS should be 127.0.0.1 (found 1.1.1.1)'),
    ('--dns 127.0.0.1 --dns 1.1.1.1', 'OK: Checks passed for /etc/resolv.conf DNS servers'),
])
def test_docker_checks_for_resolvconf_misconfiguration(Docker, args_dns, expected_stdout):
    ''' The container checks for misconfigured resolv.conf '''
    function = Docker.run('. /bash_functions.sh ; eval `grep docker_checks /start.sh`')
    print function.stdout
    assert expected_stdout in function.stdout
