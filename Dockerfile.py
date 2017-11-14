#!/usr/bin/env python

""" Dockerfile.py - generates and build dockerfiles

Usage:
  Dockerfile.py [--os=<os> ...] [--arch=<arch> ...] [-v] [--no-build | --no-generate]

Options:
    --no-build      Skip building the docker images
    --no-generate   Skip generating Dockerfiles from template
    --os=<os>       What OS(s) to build             [default: alpine debian]
    --arch=<arch>   What Architecture(s) to build   [default: amd64 armhf aarch64]
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
    's6_version' : 'v1.20.0.0',
}

os_base_vars = {
    'debian': {
        'php_env_config': '/etc/lighttpd/conf-enabled/15-fastcgi-php.conf',
        'php_error_log': '/var/log/lighttpd/error.log'
    },
    'alpine': {
        'php_env_config': '/etc/php5/fpm.d/envs.conf',
        'php_error_log': '/var/log/nginx/error.log'
    }
}

images = {
    'debian': [
        {
            'base': 'debian:jessie',
            'arch': 'amd64'
        },
        {
            'base': 'multiarch/debian-debootstrap:armhf-jessie-slim',
            'arch': 'armhf'
        },
        {
            'base': 'multiarch/debian-debootstrap:arm64-jessie-slim',
            'arch': 'aarch64'
        }
    ],
    'alpine': [
        {
            'base': 'alpine:edge',
            'arch': 'amd64'
        },
        {
            'base': 'multiarch/alpine:armhf-edge',
            'arch': 'armhf'
        },
        # Impossible combo :(
        # {
        #     'base': 'multiarch/alpine:aarch64-edge',
        #     'arch': 'aarch64'
        # }
    ]
}

def generate_dockerfiles(args):
    if args['--no-generate']:
        print " ::: Skipping Dockerfile generation"
        return

    for os, archs in images.iteritems():
        for image in archs:
            if os not in args['--os'] and image['arch'] not in args['--arch']:
                return
            merged_data = dict(
                { 'os': os }.items() +
                base_vars.items() +
                os_base_vars[os].items() +
                image.items()
            )
            j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                                 trim_blocks=True)
            template = j2_env.get_template('Dockerfile.template')

            dockerfile = 'Dockerfile_{}_{}'.format(os, image['arch'])
            with open(dockerfile, 'w') as f:
                f.write(template.render(pihole=merged_data))


def build_dockerfiles(args):
    if args['--no-build']:
        print " ::: Skipping Dockerfile generation"
        return

    for os in args['--os']:
        for arch in args['--arch']:
            docker_repo = 'pi-hole-multiarch'
            if arch == 'amd64':
                docker_repo = 'pi-hole'

            build(docker_repo, os, arch, args)


def build(docker_repo, os, arch, args):
    run_local = testinfra.get_backend(
        "local://"
    ).get_module("Command").run

    dockerfile = 'Dockerfile_{}_{}'.format(os, arch)
    repo_tag = '{}:{}_{}'.format(docker_repo, os, arch)
    cached_image = '{}/{}'.format('diginc', repo_tag)
    print " ::: Building {} into {}".format(dockerfile, repo_tag)
    build_cmd = run_local('docker build --pull --cache-from="{cache},{create_tag}" -f {dockerfile} -t {create_tag} .'\
        .format(cache=cached_image, dockerfile=dockerfile, create_tag=repo_tag))
    if args['-v']:
        print build_cmd.stdout
    if build_cmd.rc != 0:
        print "     ::: Building {} encountered an error".format(dockerfile)
        print build_cmd.stderr
    assert build_cmd.rc == 0


if __name__ == '__main__':
    args = docopt(__doc__, version='Dockerfile 0.1')
    # print args

    generate_dockerfiles(args)
    build_dockerfiles(args)
