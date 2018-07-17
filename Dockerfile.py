#!/usr/bin/env python

""" Dockerfile.py - generates and build dockerfiles

Usage:
  Dockerfile.py [--arch=<arch> ...] [--skip=<arch> ...] [-v] [--no-build | --no-generate] [--no-cache]

Options:
    --no-build      Skip building the docker images
    --no-cache      Build without using any cache data
    --no-generate   Skip generating Dockerfiles from template
    --arch=<arch>   What Architecture(s) to build   [default: amd64 armel armhf aarch64]
    --skip=<arch>   What Architectures(s) to skip   [default: None]
    -v              Print docker's command output   [default: False]

Examples:
"""

from docopt import docopt
from jinja2 import Environment, FileSystemLoader
from docopt import docopt
import os
import testinfra

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

base_vars = {
    'name': 'diginc/pi-hole',
    'maintainer' : 'adam@diginc.us',
    's6_version' : 'v1.21.4.0',
}

os_base_vars = {
    'debian': {
        'php_env_config': '/etc/lighttpd/conf-enabled/15-fastcgi-php.conf',
        'php_error_log': '/var/log/lighttpd/error.log'
    },
}

images = {
    'debian': [
        {
            'base': 'debian:stretch',
            'arch': 'amd64'
        },
        {
            'base': 'multiarch/debian-debootstrap:armel-stretch-slim',
            'arch': 'armel'
        },
        {
            'base': 'multiarch/debian-debootstrap:armhf-stretch-slim',
            'arch': 'armhf'
        },
        {
            'base': 'multiarch/debian-debootstrap:arm64-stretch-slim',
            'arch': 'aarch64'
        }
    ]
}

def generate_dockerfiles(args):
    if args['--no-generate']:
        print " ::: Skipping Dockerfile generation"
        return

    for os, archs in images.iteritems():
        for image in archs:
            if image['arch'] not in args['--arch'] or image['arch'] in args['--skip']:
                    return
            s6arch = image['arch']
            if image['arch'] == 'armel':
                s6arch = 'arm'
            merged_data = dict(
                { 'os': os }.items() +
                base_vars.items() +
                os_base_vars[os].items() +
                image.items() +
                { 's6arch': s6arch }.items()
            )
            j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                                 trim_blocks=True)
            template = j2_env.get_template('Dockerfile.template')

            dockerfile = 'Dockerfile_{}_{}'.format(os, image['arch'])
            with open(dockerfile, 'w') as f:
                f.write(template.render(pihole=merged_data))


def build_dockerfiles(args):
    if args['--no-build']:
        print " ::: Skipping Dockerfile building"
        return

    for arch in args['--arch']:
        docker_repo = 'pi-hole-multiarch'
        if arch == 'amd64':
            docker_repo = 'pi-hole'

        build(docker_repo, 'debian', arch, args)


def build(docker_repo, os, arch, args):
    run_local = testinfra.get_backend(
        "local://"
    ).get_module("Command").run

    dockerfile = 'Dockerfile_{}_{}'.format(os, arch)
    repo_tag = '{}:{}_{}'.format(docker_repo, os, arch)
    cached_image = '{}/{}'.format('diginc', repo_tag)
    no_cache = ''
    if args['--no-cache']:
        no_cache = '--no-cache'
    build_command = 'docker build {no_cache} --pull --cache-from="{cache},{create_tag}" -f {dockerfile} -t {create_tag} .'\
        .format(no_cache=no_cache, cache=cached_image, dockerfile=dockerfile, create_tag=repo_tag)
    print " ::: Building {} into {}".format(dockerfile, repo_tag)
    if args['-v']:
        print build_command, '\n'
    build_result = run_local(build_command) 
    if args['-v']:
        print build_result.stdout
    if build_result.rc != 0:
        print "     ::: Building {} encountered an error".format(dockerfile)
        print build_result.stderr
    assert build_result.rc == 0


if __name__ == '__main__':
    args = docopt(__doc__, version='Dockerfile 0.2')
    # print args

    generate_dockerfiles(args)
    build_dockerfiles(args)
