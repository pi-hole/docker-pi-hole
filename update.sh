#!/bin/bash

git submodule foreach git pull origin master;
cp pi-hole/gravity.sh alpine/;
sed -i '/^gravity_reload/ c\#gravity_reload' alpine/gravity.sh
pushd pi-hole ; git describe --tags --abbrev=0 > ../pi-hole_version.txt ; popd ;
pushd AdminLTE ; git describe --tags --abbrev=0 > ../AdminLTE_version.txt ; popd ;
