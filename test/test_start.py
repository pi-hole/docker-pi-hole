import pytest
import time
''' conftest.py provides the defaults through fixtures '''
''' Note, testinfra builtins don't seem fully compatible with
        docker containers (esp. alpine) stripped down nature '''

WEB_CONFIG = { 'alpine': '/etc/nginx/nginx.conf', 'debian': '/etc/lighttpd/lighttpd.conf' }
IPV6_LINE = { 'alpine': 'listen \[::\]:80', 'debian': 'use-ipv6.pl' }

def test_pihole_default_run_command(Docker):
    expected_proc = '/sbin/tini -- /start.sh'
    pgrep = 'pgrep -f "{}" | wc -l || echo 0'.format(expected_proc)
    find_proc = Docker.run(pgrep).stdout
    if int(find_proc) < 1:
        print Docker.run('ps -ef')
        print "{} : {}".format(pgrep, find_proc)
        assert False, '{}: Couldn\'t find proc {}'.format(tag, expected_proc)

@pytest.mark.parametrize('args', [ '' ])
@pytest.mark.parametrize('cmd', [ 'tail -f /dev/null' ])
def test_ServerIP_missing_triggers_start_error(Docker):
    ''' When args to docker are empty start.sh exits saying ServerIP is required '''
    start = Docker.run('/start.sh')
    error_msg = "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container"
    assert start.rc == 1
    assert error_msg in start.stdout


@pytest.mark.parametrize('args,expected_ipv6,expected_stdout', [
    ('-e ServerIP="1.2.3.4"', True, 'IPv4 and IPv6'),
    ('-e ServerIP="1.2.3.4" -e "IPv6=True"', True, 'IPv4 and IPv6'),
    ('-e ServerIP="1.2.3.4" -e "IPv6=False"', False, 'IPv4'),
    ('-e ServerIP="1.2.3.4" -e "IPv6=foobar"', False, 'IPv4'),
])
@pytest.mark.parametrize('cmd', [ 'tail -f /dev/null' ])
def test_IPv6_not_True_removes_ipv6(Docker, tag, args, expected_ipv6, expected_stdout):
    ''' When a user overrides IPv6=True they only get IPv4 listening webservers '''
    function = Docker.run('. /bash_functions.sh ; setup_ipv4_ipv6')
    assert "Using {}".format(expected_stdout) in function.stdout
    ipv6 = Docker.run('grep -q \'{}\' {}'.format(IPV6_LINE[tag], WEB_CONFIG[tag])).rc == 0
    assert ipv6 == expected_ipv6

@pytest.mark.parametrize('args, expected_stdout, dns1, dns2', [
    ('-e ServerIP="1.2.3.4"', 'default DNS', '8.8.8.8', '8.8.4.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4"', 'custom DNS', '1.2.3.4', '8.8.4.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS2="1.2.3.4"', 'custom DNS', '8.8.8.8', '1.2.3.4' ),
    ('-e ServerIP="1.2.3.4" -e DNS1="1.2.3.4" -e DNS2="2.2.3.4"', 'custom DNS', '1.2.3.4', '2.2.3.4' ),
])
@pytest.mark.parametrize('cmd', [ 'tail -f /dev/null' ])
def test_DNS_Envs_override_defaults(Docker, args, expected_stdout, dns1, dns2):
    ''' When DNS environment vars are passed in, they override default dns servers '''
    function = Docker.run('. /bash_functions.sh ; eval `grep setup_dnsmasq_dns /start.sh`')
    assert expected_stdout in function.stdout

    docker_dns_servers = Docker.run('grep "^server=" /etc/dnsmasq.d/01-pihole.conf').stdout
    expected_servers = 'server={}\nserver={}\n'.format(dns1, dns2)
    assert expected_servers == docker_dns_servers

''' 
Persistent Docker container for testing service post start.sh 
'''
@pytest.fixture
def RunningPiHole(DockerPersist, Slow, persist_webserver):
    ''' Persist a fully started docker-pi-hole to help speed up subsequent tests '''
    Slow(lambda: DockerPersist.run('pgrep {}'.format(persist_webserver) ).rc == 0)
    Slow(lambda: DockerPersist.run('pgrep dnsmasq').rc == 0)
    return DockerPersist

@pytest.mark.parametrize('hostname,expected_ip', [
    ('pi.hole',                        '192.168.100.2'),
    ('google-public-dns-a.google.com', '8.8.8.8'),
    ('b.resolvers.Level3.net',         '4.2.2.2')
])
def test_dns_responses(RunningPiHole, hostname, expected_ip):
    dig_cmd = "dig +time=1 +noall +answer {} @test_pihole | awk '{{ print $5 }}'".format(hostname)
    lookup = RunningPiHole.dig.run(dig_cmd).stdout.rstrip('\n')
    assert lookup == expected_ip

def test_indecies_are_present(RunningPiHole):
    File = RunningPiHole.get_module('File')
    File('/var/www/html/pihole/index.html').exists
    File('/var/www/html/pihole/index.js').exists

@pytest.mark.parametrize('ip', [ '127.0.0.1', '[::]' ] )
@pytest.mark.parametrize('url', [ '/', '/index.html', '/any.html' ] )
def test_html_index_requests_load_as_expected(RunningPiHole, ip, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(ip, url)
    http_rc = RunningPiHole.run(command)
    assert RunningPiHole.run('md5sum /tmp/curled_file /var/www/html/pihole/index.html').rc == 0
    assert int(http_rc.stdout) == 200

@pytest.mark.parametrize('ip', [ '127.0.0.1', '[::]' ] )
@pytest.mark.parametrize('url', [ '/index.js', '/any.js'] )
def test_javascript_requests_load_as_expected(RunningPiHole, ip, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(ip, url)
    http_rc = RunningPiHole.run(command)
    assert RunningPiHole.run('md5sum /tmp/curled_file /var/www/html/pihole/index.js').rc == 0
    assert int(http_rc.stdout) == 200

@pytest.mark.parametrize('ip', [ '127.0.0.1', '[::]' ] )
@pytest.mark.parametrize('url', [ '/admin/', '/admin/index.php' ] )
def test_admin_requests_load_as_expected(RunningPiHole, ip, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(ip, url)
    http_rc = RunningPiHole.run(command)
    assert int(http_rc.stdout) == 200
    assert RunningPiHole.run('wc -l /tmp/curled_file ') > 10
    assert RunningPiHole.run('grep -q "Content-Security-Policy" /tmp/curled_file ').rc == 0
    assert RunningPiHole.run('grep -q "js/pihole/footer.js" /tmp/curled_file ').rc == 0
