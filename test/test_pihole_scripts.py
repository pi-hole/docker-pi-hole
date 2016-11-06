import pytest

RESTART_DNS_STDOUT = { 
    'alpine': '',
    'debian': 'Restarting DNS forwarder and DHCP server: dnsmasq.\n'
}
def test_pihole_restartdns(RunningPiHole, Slow, persist_tag):
    ''' ensure a new pid for dnsmasq appears and we have stdout as expected '''
    oldpid = RunningPiHole.run('pidof dnsmasq')
    restartdns = RunningPiHole.run('pihole restartdns')
    Slow(lambda: RunningPiHole.run('pgrep dnsmasq').rc == 0)
    newpid = RunningPiHole.run('pidof dnsmasq')
    for pid in [oldpid, newpid]:
        assert pid != ''
    assert oldpid != newpid
    assert restartdns.rc == 0
    assert restartdns.stdout == RESTART_DNS_STDOUT[persist_tag]
