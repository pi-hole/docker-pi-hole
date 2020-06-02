#!/usr/bin/env python3
""" Dockerfile.py - generates and build dockerfiles

Usage:
  Dockerfile.py [--hub_tag=<tag>] [--arch=<arch> ...] [-v] [-t] [--no-build] [--no-cache]

Options:
    --no-build      Skip building the docker images
    --no-cache      Build without using any cache data
    --hub_tag=<tag> What the Docker Hub Image should be tagged as [default: None]
    --arch=<arch>   What Architecture(s) to build   [default: amd64 armel armhf arm64]
    -v              Print docker's command output   [default: False]
    -t              Print docker's build time       [default: False]

Examples:
"""


from docopt import docopt
import os
import subprocess

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

__version__ = None
dot = os.path.abspath('.')
with open('{}/VERSION'.format(dot), 'r') as v:
    raw_version = v.read().strip()
    __version__ = raw_version.replace('release/', 'release-')


def build_dockerfiles(args):
    if args['--no-build']:
        print(" ::: Skipping Dockerfile building")
        return

    for arch in args['--arch']:
        build('pihole', arch, args)


def run_and_stream_command_output(command, args):
    print("Running", command)
    build_env = os.environ.copy()
    build_env['PIHOLE_VERSION'] = __version__
    build_result = subprocess.Popen(command.split(), env=build_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    bufsize=1, universal_newlines=True)
    if args['-v']:
        while build_result.poll() is None:
            for line in build_result.stdout:
                print(line, end='')
    build_result.wait()
    if build_result.returncode != 0:
        print("     ::: Error running".format(command))
        print(build_result.stderr)


def build(docker_repo, arch, args):
    repo_tag = '{}:{}-{}'.format(docker_repo, __version__, arch)
    print(" ::: Building {}".format(repo_tag))
    time = ''
    if args['-t']:
        time = 'time '
    no_cache = ''
    if args['--no-cache']:
        no_cache = '--no-cache'
    build_command = '{time}docker-compose -f build.yml build {no_cache} --pull {arch}'\
        .format(time=time, no_cache=no_cache, arch=arch)
    print(" ::: Building {} into {}".format(arch, repo_tag))
    run_and_stream_command_output(build_command, args)
    if args['-v']:
        print(build_command, '\n')
    if args['--hub_tag']:
        hub_tag_command = "{time}docker tag {create_tag} {hub_tag}"\
            .format(time=time, create_tag=repo_tag, hub_tag=args['--hub_tag'])
        print(" ::: Tagging {} into {}".format(repo_tag, args['--hub_tag']))
        run_and_stream_command_output(hub_tag_command, args)


if __name__ == '__main__':
    args = docopt(__doc__, version='Dockerfile 1.1')
    if args['-v']:
        print(args)

    build_dockerfiles(args)
