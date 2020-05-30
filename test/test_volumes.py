import subprocess

def run_and_stream_command_output(command, verbose=False):
    print("Running", command)
    build_env = os.environ.copy()
    build_env['PIHOLE_VERSION'] = __version__
    build_result = subprocess.Popen(command.split(), env=build_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    bufsize=1, universal_newlines=True)
    if verbose:
        while build_result.poll() is None:
            for line in build_result.stdout:
                print(line, end='')
    build_result.wait()
    if build_result.returncode != 0:
        print("     ::: Error running".format(command))
        print(build_result.stderr)

def test_volume_shell_script(arch):
    # only one arch should be necessary
    if arch == 'amd64':
        run_and_stream_command_output('./test/test_volume_data.sh')


def test_fail():
    assert 1 == 2
