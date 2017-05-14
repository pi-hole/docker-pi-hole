import pytest
import testinfra

run_local = testinfra.get_backend(
    "local://"
).get_module("Command").run

def test_scripts_pass_shellcheck():
    ''' Make sure shellcheck does not find anything wrong with our shell scripts '''
    shellcheck = "find . -name '*.sh' -a ! ( -name 'list.sh' ) | while read file; do shellcheck -e SC1008 $file; done;"
    results = run_local(shellcheck)
    print results.stdout
    assert '' == results.stdout
