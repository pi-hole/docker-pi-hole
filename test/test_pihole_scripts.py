import pytest


@pytest.fixture(scope='module')
def start_cmd():
    ''' broken by default, required override '''
    return None


@pytest.fixture
def RunningPiHole(DockerPersist, Slow, persist_webserver, persist_tag, start_cmd):
    ''' Override the RunningPiHole to run and check for success of a
        pihole-FTL start based `pihole` script command
        
        Individual tests all must override start_cmd'''
    #print DockerPersist.run('ps -ef').stdout
    assert DockerPersist.dig.run('ping -c 1 test_pihole').rc == 0
    Slow(lambda: DockerPersist.run('pgrep pihole-FTL').rc == 0)
    Slow(lambda: DockerPersist.run('pgrep {}'.format(persist_webserver)).rc == 0)
    oldpid = DockerPersist.run('pidof pihole-FTL')
    cmd = DockerPersist.run('pihole {}'.format(start_cmd))
    Slow(lambda: DockerPersist.run('pgrep pihole-FTL').rc == 0)
    newpid = DockerPersist.run('pidof pihole-FTL')
    for pid in [oldpid, newpid]:
        assert pid != ''
    # ensure a new pid for pihole-FTL appeared due to service restart
    assert oldpid != newpid
    assert cmd.rc == 0
    # Save out cmd result to check different stdout of start/enable/disable
    DockerPersist.cmd = cmd
    return DockerPersist


@pytest.mark.parametrize('start_cmd,hostname,expected_ip, expected_messages', [
    ('enable',  'pi.hole', '127.0.0.1', ['Blocking already enabled,','nothing to do']),
    ('disable', 'pi.hole', '127.0.0.1', ['Disabling blocking','Pi-hole Disabled']),
])
def test_pihole_enable_disable_command(RunningPiHole, Dig, persist_tag, start_cmd, hostname, expected_ip, expected_messages):
    ''' the start_cmd tests are all built into the RunningPiHole fixture in this file '''
    dig_cmd = "dig +time=1 +noall +answer {} @test_pihole".format(hostname)
    lookup = RunningPiHole.dig.run(dig_cmd)
    assert lookup.rc == 0
    lookup_ip = lookup.stdout.split()[4]
    assert lookup_ip == expected_ip

    for part_of_output in expected_messages:
        assert part_of_output in RunningPiHole.cmd.stdout

@pytest.mark.parametrize('start_cmd,expected_message', [
    ('-up', 'Function not supported in Docker images')
])
def test_pihole_update_command(RunningPiHole, start_cmd, expected_message):
    assert RunningPiHole.cmd.stdout.strip() == expected_message

