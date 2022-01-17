#!/usr/bin/with-contenv bash
set -e

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi

modifyUser()
{
  declare username=${1:-} newId=${2:-}
  [[ -z ${username} || -z ${newId} ]] && return

  local currentId=$(id -u ${username})
  [[ ${currentId} -eq ${newId} ]] && return

  echo "Changing ID for user: ${username} (${currentId} => ${newId})"
  usermod -o -u ${newId} ${username}  
}

modifyGroup()
{
  declare groupname=${1:-} newId=${2:-}
  [[ -z ${groupname} || -z ${newId} ]] && return

  local currentId=$(id -g ${groupname})
  [[ ${currentId} -eq ${newId} ]] && return

  echo "Changing ID for group: ${groupname} (${currentId} => ${newId})"
  groupmod -o -g ${newId} ${groupname}
}

modifyUser www-data ${WEB_UID}
modifyGroup www-data ${WEB_GID}
modifyUser pihole ${PIHOLE_UID}
modifyGroup pihole ${PIHOLE_GID}