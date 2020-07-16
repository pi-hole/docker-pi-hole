#!/usr/bin/env python3
""" Dockerfile.py - generates and build dockerfiles

Usage:
  Dockerfile.py [--hub_tag=<tag>] [--arch=<arch> ...] [--debian=<version> ...] [-v] [-t] [--no-build] [--no-cache] [--fail-fast]

Options:
    --no-build           Skip building the docker images
    --no-cache           Build without using any cache data
    --fail-fast          Exit on first build error
    --hub_tag=<tag>      What the Docker Hub Image should be tagged as [default: None]
    --arch=<arch>        What Architecture(s) to build     [default: amd64 armel armhf arm64]
    --debian=<version>   What debian version(s) to build   [default: stretch buster]
    -v                   Print docker's command output     [default: False]
    -t                   Print docker's build time         [default: False]

Examples:
"""
from docopt import docopt
import os
import sys
import subprocess

__version__ = None
dot = os.path.abspath('.')
with open('{}/VERSION'.format(dot), 'r') as v:
    raw_version = v.read().strip()
    __version__ = raw_version.replace('release/', 'release-')


def build_dockerfiles(args) -> bool:
    all_success = True
    if args['-v']:
        print(args)
    if args['--no-build']:
        print(" ::: Skipping Dockerfile building")
        return all_success

    for arch in args['--arch']:
        for debian_version in args['--debian']:
            all_success = build('pihole', arch, debian_version, args['--hub_tag'], args['-t'], args['--no-cache'], args['-v']) and all_success
            if not all_success and args['--fail-fast']:
                return False
    return all_success


def run_and_stream_command_output(command, environment_vars, verbose) -> bool:
    print("Running", command)
    build_result = subprocess.Popen(command.split(), env=environment_vars, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, bufsize=1, universal_newlines=True)
    if verbose:
        while build_result.poll() is None:
            for line in build_result.stdout:
                print(line, end='')
    build_result.wait()
    if build_result.returncode != 0:
        print("     ::: Error running".format(command))
        print(build_result.stderr)
    return build_result.returncode == 0


def build(docker_repo: str, arch: str, debian_version: str, hub_tag: str, show_time: bool, no_cache: bool, verbose: bool) -> bool:
    create_tag = f'{docker_repo}:{__version__}-{arch}-{debian_version}'
    print(f' ::: Building {create_tag}')
    time_arg = 'time' if show_time else ''
    cache_arg = '--no-cache' if no_cache else ''
    build_env = os.environ.copy()
    build_env['PIHOLE_VERSION'] = __version__
    build_env['DEBIAN_VERSION'] = debian_version
    build_command = f'{time_arg} docker-compose -f build.yml build {cache_arg} --pull {arch}'
    print(f' ::: Building {arch} into {create_tag}')
    success = run_and_stream_command_output(build_command, build_env, verbose)
    if verbose:
        print(build_command, '\n')
    if success and hub_tag:
        hub_tag_command = f'{time_arg} docker tag {create_tag} {hub_tag}'
        print(f' ::: Tagging {create_tag} into {hub_tag}')
        success = run_and_stream_command_output(hub_tag_command, build_env, verbose)
    return success


if __name__ == '__main__':
    args = docopt(__doc__, version='Dockerfile 1.1')
    success = build_dockerfiles(args)
    exit_code = 0 if success else 1
    sys.exit(exit_code)
