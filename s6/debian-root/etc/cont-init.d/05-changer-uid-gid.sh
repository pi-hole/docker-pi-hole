#!/usr/bin/with-contenv bash
set -e

modifyUser()
{
  declare username=${1:-} newId=${2:-}
  [[ -z ${username} || -z ${newId} ]] && return

  local currentId=$(id -u ${username})
  [[ ${currentId} -eq ${newId} ]] && return

  echo "user ${username} ${currentId} => ${newId}"
  usermod -o -u ${newId} ${username}

  find / -user ${currentId} -print0 2> /dev/null | \
    xargs -0 -n1 chown -h ${username} 2> /dev/null
}

modifyGroup()
{
  declare groupname=${1:-} newId=${2:-}
  [[ -z ${groupname} || -z ${newId} ]] && return

  local currentId=$(id -g ${groupname})
  [[ ${currentId} -eq ${newId} ]] && return

  echo "group ${groupname} ${currentId} => ${newId}"
  groupmod -o -g ${newId} ${groupname}

  find / -group ${currentId} -print0 2> /dev/null | \
    xargs -0 -n1 chgrp -h ${groupname} 2> /dev/null
}

modifyUser www-data ${WEB_UID}
modifyGroup www-data ${WEB_GID}
modifyUser pihole ${PIHOLE_UID}
modifyGroup pihole ${PIHOLE_GID}
