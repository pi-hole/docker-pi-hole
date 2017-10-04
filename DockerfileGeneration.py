from jinja2 import Environment, FileSystemLoader
import os

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
        {
            'base': 'multiarch/alpine:aarch64-edge',
            'arch': 'aarch64'
        }
    ]
}

def generate_dockerfiles():
    for os, archs in images.iteritems():
        for image in archs:
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


if __name__ == '__main__':
    generate_dockerfiles()
