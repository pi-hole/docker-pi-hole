import pytest
import testinfra

# Use testinfra to get a handy function to run commands locally
check_output = testinfra.get_backend(
    "local://"
).get_module("Command").check_output


@pytest.fixture
def TestinfraBackend(request):
    docker_run = "docker run -d {}".format(request.param)
    print docker_run

    docker_id = check_output(docker_run)
    check_output("docker exec %s sed -i 's/^gravity_spinup/#donotcurl/g' /usr/local/bin/gravity.sh", docker_id)

    def teardown():
        check_output("docker rm -f %s", docker_id)
    request.addfinalizer(teardown)

    return testinfra.get_backend("docker://" + docker_id)


def pytest_generate_tests(metafunc):
    if "TestinfraBackend" in metafunc.fixturenames:

        mark_args = getattr(metafunc.function, "docker_args", None)
        docker_args = []
        if mark_args is not None:
            docker_args = docker_args + list(mark_args.args)

        mark_images = getattr(metafunc.function, "docker_images", None)
        images = ['diginc/pi-hole:alpine', 'diginc/pi-hole:debian']
        if mark_images is not None:
            images = mark_images.args

        mark_cmd = getattr(metafunc.function, "docker_cmd", None)
        command = 'tail -f /dev/null'
        if mark_cmd is not None:
            command = " ".join(mark_cmd.args)

        docker_run_args = []
        for img in images:
            docker_run_args.append('{} {} {}'.format(" ".join(docker_args),
                                                  img, command))
        if getattr(metafunc.function, "persistent", None) is not None:
            scope = "session"
        else:
            scope = "function"

        metafunc.parametrize(
            "TestinfraBackend", docker_run_args, indirect=True, scope=scope)
