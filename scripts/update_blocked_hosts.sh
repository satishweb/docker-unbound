#!/bin/sh
# Author: Satish Gaikwad <satish@satishweb.com>
#
# shellcheck disable=SC2154
# The variables of the block list sources and of the white list are read from
# the environment, the entrypoint writes them into the cron job.

# The variables of the block list sources and the white list are read from
# the environment. The entrypoint writes them into the cron job, so the daily
# update uses the same settings as the container.

if [ "$1" = "" ]; then
  UNBOUND_BLOCKED_HOSTS_FILE=/etc/unbound/unbound.blocked.hosts
else
  UNBOUND_BLOCKED_HOSTS_FILE="$1"
fi

checkErr() {
  # $1 = error code
  # $2 = error message
  if [ "$1" != "0" ]; then
    echo "| ERR: $2"
    exit "$1"
  fi
}

: > /tmp/hosts

# Download StevenBlack's Hosts files

if [ "${SOURCE_StevenBlack_Unified_Hosts}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Unified hosts = (adware + malware) file... "
  curl -fsSL https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts -o /tmp/hosts.unified
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.unified >> /tmp/hosts
fi

if [ "${SOURCE_StevenBlack_Fakenews}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Fakenews hosts file... "
  curl -fsSL https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts -o /tmp/hosts.fakenews
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.fakenews >> /tmp/hosts
fi

if [ "${SOURCE_StevenBlack_Gambling}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Gambling hosts file... "
  curl -fsSL https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling/hosts -o /tmp/hosts.gambling
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.gambling >> /tmp/hosts
fi

if [ "${SOURCE_StevenBlack_Porn}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Porn hosts file... "
  curl -fsSL https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts -o /tmp/hosts.porn
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.porn >> /tmp/hosts
fi

if [ "${SOURCE_TheGreatWall_Default}" = "true" ]; then
  echo "| INFO: Downloading TheGreatWall hosts file... "
  curl -fsSL https://raw.githubusercontent.com/Sekhan/TheGreatWall/master/TheGreatWall.txt -o /tmp/hosts.greatwall
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.greatwall >> /tmp/hosts
fi

if [ "${SOURCE_AdWars_Default}" = "true" ]; then
  echo "| INFO: Downloading AdWars hosts file... "
  curl -fsSL https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts -o /tmp/hosts.adwars
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.adwars >> /tmp/hosts
fi

if [ "${SOURCE_VeleSila_Default}" = "true" ]; then
  echo "| INFO: Downloading VeleSila hosts file... "
  curl -fsSL https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts -o /tmp/hosts.velesila
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.velesila >> /tmp/hosts
fi

if [ "${SOURCE_Tiuxo_Default}" = "true" ]; then
  echo "| INFO: Downloading Tiuxo ad blocks hosts file... "
  curl -fsSL https://raw.githubusercontent.com/tiuxo/hosts/master/ads -o /tmp/hosts.tiuxo
  checkErr "$?" "Download failed!"
  cat /tmp/hosts.tiuxo >> /tmp/hosts
fi

# Update unbound config
echo "| INFO: Updating unbound host zones..."
grep '^0\.0\.0\.0' /tmp/hosts \
  | awk '{print "local-zone: \""$2"\" redirect\nlocal-data: \""$2" A 0.0.0.0\""}' \
  | sort -u > "${UNBOUND_BLOCKED_HOSTS_FILE}"

chown -f unbound:unbound "${UNBOUND_BLOCKED_HOSTS_FILE}" 2>/dev/null || true

# Remove whitelisted domains from the block list
if [ "${DOMAIN_WHITELIST}" != "" ]; then
  for i in ${DOMAIN_WHITELIST}; do
    echo "| INFO: Removing ${i} from the block list..."
    sed -i "/.*${i}.*/d" "${UNBOUND_BLOCKED_HOSTS_FILE}"
  done
fi

# Reload config
if [ "$2" != "no-reload" ]; then
  if ! unbound-control reload >/dev/null 2>&1; then
    echo "| WARN: unbound reload failed, trying to restart service..."
    supervisorctl restart unbound
    checkErr "$?" "Unbound service restart failed!"
  fi
fi
