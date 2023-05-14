#!/bin/sh
# Author: Satish Gaikwad <satish@satishweb.com>

. /etc/profile

if [ "$1" == "" ]; then
  UNBOUND_BLOCKED_HOSTS_FILE=/etc/unbound/unbound.blocked.hosts
else
  UNBOUND_BLOCKED_HOSTS_FILE="$1"
fi

checkErr() {
  # $1 = error code
  # $2 = error message
  if [ "$1" != "0" ]; then
    echo "| ERR: $2"
    exit $1
  fi
}

touch /tmp/hosts; truncate -s 0 /tmp/hosts

# Download StevenBlack's Hosts files

if [ "${SOURCE_StevenBlack_Unified_Hosts}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Unified hosts = (adware + malware) file... "
  curl https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

if [ "${SOURCE_StevenBlack_Fakenews}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Unified hosts + Fakenews file... "
  curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

if [ "${SOURCE_StevenBlack_Gambling}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Unified hosts + Gambling file... "
  curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling/hosts --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

if [ "${SOURCE_StevenBlack_Porn}" = "true" ]; then
  echo "| INFO: Downloading StevenBlack Unified hosts + Porn file... "
  curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

# Download DoH Hosts file
if [ "${SOURCE_TheGreatWall_Default}" = "true" ]; then
  echo "| INFO: Downloading TheGreatWall DoH hosts file... "
  curl https://raw.githubusercontent.com/Sekhan/TheGreatWall/master/TheGreatWall.txt --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

# Download ad wars Hosts file
if [ "${SOURCE_AdWars_Default}" = "true" ]; then
  echo "| INFO: Downloading AdWars blocks hosts file... "
  curl https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

# Download ad wars Hosts file
if [ "${SOURCE_VeleSila_Default}" = "true" ]; then
  echo "| INFO: Downloading VeleSila ad blocks hosts file... "
  curl https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

# Download Tiuxo Hosts file
if [ "${SOURCE_Tiuxo_Default}" = "true" ]; then
  echo "| INFO: Downloading Tiuxo ad blocks hosts file... "
  curl https://raw.githubusercontent.com/tiuxo/hosts/master/ads --insecure | tee -a /tmp/hosts >/dev/null 2>&1
  checkErr $? "Download failed!"
fi

# Update unbound config
echo "| INFO: Updating unbound host zones..."
cat /tmp/hosts | grep '^0\.0\.0\.0' | awk '{print "local-zone: \""$2"\" redirect\nlocal-data: \""$2" A 0.0.0.0\""}' | sort -u > ${UNBOUND_BLOCKED_HOSTS_FILE}

chown -Rf unbound:unbound ${UNBOUND_BLOCKED_HOSTS_FILE}

# Remove whitelisted domains from the block list
if [ "${DOMAIN_WHITELIST}" != "" ]; then
  for i in ${DOMAIN_WHITELIST}
  do
    sed "/.*${i}.*/d" ${UNBOUND_BLOCKED_HOSTS_FILE}
  done
fi

# Reload config
if [ "${2}" != "no-reload" ]; then
  unbound-control reload >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    echo "| WARN: unbound reload failed, trying to restart service..."
    supervisorctl restart unbound
    checkErr $? "Unbound service restart failed!"
  fi
fi
