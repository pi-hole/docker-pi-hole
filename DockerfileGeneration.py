from jinja2 import Environment, FileSystemLoader
import os

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

base_vars = {
    'name': 'diginc/pi-hole',
    'maintainer' : 'adam@diginc.us',
    's6_version' : 'v1.20.0.0',
}

images = {
    'debian': [
        dict(base_vars.items() + { 
            'base': 'debian:jessie',
            'arch': 'amd64'
        }.items()),
        dict(base_vars.items() + { 
            'base': 'multiarch/debian-debootstrap:armhf-jessie-slim',
            'arch': 'armhf'
        }.items()),
        dict(base_vars.items() + { 
            'base': 'multiarch/debian-debootstrap:arm64-jessie-slim',
            'arch': 'aarch64'
        }.items()),
    ],
    'alpine': [
        dict(base_vars.items() + { 
            'base': 'alpine:edge',
            'arch': 'amd64'
        }.items()),
        dict(base_vars.items() + { 
            'base': 'multiarch/alpine:armhf-edge',
            'arch': 'armhf'
        }.items()),
        dict(base_vars.items() + { 
            'base': 'multiarch/alpine:aarch64-edge',
            'arch': 'aarch64'
        }.items())
    ]
}

def generate_dockerfiles():
    for os, archs in images.iteritems():
        for image in archs:
            j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                                 trim_blocks=True)
            template = j2_env.get_template('Dockerfile_{}.template'.format(os))
            
            Dockerfile = 'Dockerfile_{}_{}'.format(os, image['arch'])
            with open(Dockerfile, 'w') as f:
                f.write(template.render(os=os, image=image))

if __name__ == '__main__':
    generate_dockerfiles()
