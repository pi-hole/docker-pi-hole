#!/usr/bin/env python
""" Dockerfile.py - generates and build dockerfiles

Usage:
  Dockerfile.py [--arch=<arch> ...] [--skip=<arch> ...] [-v] [-t] [--no-build | --no-generate] [--no-cache]

Options:
    --no-build      Skip building the docker images
    --no-cache      Build without using any cache data
    --no-generate   Skip generating Dockerfiles from template
    --arch=<arch>   What Architecture(s) to build   [default: amd64 armel armhf aarch64]
    --skip=<arch>   What Architectures(s) to skip   [default: None]
    -v              Print docker's command output   [default: False]
    -t              Print docker's build time       [default: False]

Examples:
"""

from docopt import docopt
from jinja2 import Environment, FileSystemLoader
from docopt import docopt
import os
import testinfra

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

base_vars = {
    'name': 'pihole/pihole',
    'maintainer' : 'adam@diginc.us',
    's6_version' : 'v1.21.7.0',
}

os_base_vars = {
    'php_env_config': '/etc/lighttpd/conf-enabled/15-fastcgi-php.conf',
    'php_error_log': '/var/log/lighttpd/error.log'
}

__version__ = None
dot = os.path.abspath('.')
with open('{}/VERSION'.format(dot), 'r') as v:
    raw_version = v.read().strip()
    __version__ = raw_version.replace('release/', 'release-')

images = {
    __version__: [
        {
            'base': 'pihole/debian-base:latest',
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

    for version, archs in images.iteritems():
        for image in archs:
            if image['arch'] not in args['--arch'] or image['arch'] in args['--skip']:
                    return
            s6arch = image['arch']
            if image['arch'] == 'armel':
                s6arch = 'arm'
            merged_data = dict(
                { 'version': version }.items() +
                base_vars.items() +
                os_base_vars.items() +
                image.items() +
                { 's6arch': s6arch }.items()
            )
            j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                                 trim_blocks=True)
            template = j2_env.get_template('Dockerfile.template')

            dockerfile = 'Dockerfile_{}'.format(image['arch'])
            with open(dockerfile, 'w') as f:
                f.write(template.render(pihole=merged_data))


def build_dockerfiles(args):
    if args['--no-build']:
        print " ::: Skipping Dockerfile building"
        return

    for arch in args['--arch']:
        # TODO: include from external .py that can be shared with Dockerfile.py / Tests / deploy scripts '''
        if arch == 'armel':
            print "Skipping armel, incompatible upstream binaries/broken"
            continue
        build('pihole', arch, args)


def build(docker_repo, arch, args):
    run_local = testinfra.get_backend(
        "local://"
    ).get_module("Command").run

    dockerfile = 'Dockerfile_{}'.format(arch)
    repo_tag = '{}:{}_{}'.format(docker_repo, __version__, arch)
    cached_image = '{}/{}'.format('pihole', repo_tag)
    time=''
    if args['-t']:
        time='time '
    no_cache = ''
    if args['--no-cache']:
        no_cache = '--no-cache'
    build_command = '{time}docker build {no_cache} --pull --cache-from="{cache},{create_tag}" -f {dockerfile} -t {create_tag} .'\
        .format(time=time, no_cache=no_cache, cache=cached_image, dockerfile=dockerfile, create_tag=repo_tag)
    print " ::: Building {} into {}".format(dockerfile, repo_tag)
    if args['-v']:
        print build_command, '\n'
    build_result = run_local(build_command) 
    if args['-v']:
        print build_result.stdout
        print build_result.stderr
    if build_result.rc != 0:
        print "     ::: Building {} encountered an error".format(dockerfile)
        print build_result.stderr
    assert build_result.rc == 0


if __name__ == '__main__':
    args = docopt(__doc__, version='Dockerfile 1.0')
    # print args

    generate_dockerfiles(args)
    build_dockerfiles(args)
