#!/bin/bash -x

# Grab newest code and update version files
git submodule foreach git pull;
git submodule foreach git pull origin master;
pushd pi-hole ; git describe --tags --abbrev=0 > ../pi-hole_version.txt ; popd ;
pushd AdminLTE ; git describe --tags --abbrev=0 > ../AdminLTE_version.txt ; popd ;

# Copy latest crontab and modify to use docker exec commands
cron='./docker-pi-hole.cron'
cp -f pi-hole/advanced/pihole.cron ${cron};
sed -i '/Update the ad sources/ i\# Your container name goes here:\nDOCKER_NAME=pihole\nPATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n' ${cron};
sed -i 's|/usr/local/bin/|docker exec $DOCKER_NAME |g' ${cron};
sed -i '/docker exec/ s|$| > /dev/null|g' ${cron};

# docker-pi-hole users update their docker images, not git code
sed -i '/Update Pi-hole/ a\# pihole software update commands are unsupported in docker!' ${cron};
sed -i '/Update Pi-hole/ c\# Update docker-pi-hole by pulling the latest docker image ane re-creating your container.' ${cron};
sed -i '/pihole updateDashboard/ s/^/#/' ${cron};
