def test_volume_shell_script(arch, run_and_stream_command_output):
    # only one arch should be necessary
    if arch == 'amd64':
        run_and_stream_command_output('./test/test_volume_data.sh')
