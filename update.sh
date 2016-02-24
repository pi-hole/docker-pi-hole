#!/bin/bash

git submodule foreach git pull origin master
cp pi-hole/gravity.sh alpine/
sed -i '/^gravity_reload/ c\#gravity_reload' alpine/gravity.sh
