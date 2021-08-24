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
  if [[ "$1" != "0" ]]; then
    echo "| ERR: $2"
    exit $1
  fi
}

# Download blocked hosts:
echo "| INFO: Downloading Blocked hosts file... "
curl https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts --insecure --output /tmp/hosts >/dev/null 2>&1
checkErr $? "Download failed!"

# Update unbound config
echo "| INFO: Updating unbound host zones..."
cat /tmp/hosts | grep '^0\.0\.0\.0' | awk '{print "local-zone: \""$2"\" redirect\nlocal-data: \""$2" A 0.0.0.0\""}' > ${UNBOUND_BLOCKED_HOSTS_FILE}
chown -Rf unbound:unbound ${UNBOUND_BLOCKED_HOSTS_FILE}

# Remove whitelisted domains from the block list
if [ "${DOMAIN_WHITELIST}" != "" ]; then
  for i in ${DOMAIN_WHITELIST}
  do
    sed "/.*${i}.*/d" ${UNBOUND_BLOCKED_HOSTS_FILE}
  done
fi

# Reload config
if [[ "${2}" != "no-reload" ]]; then
  unbound-control reload >/dev/null 2>&1
  if [[ "$?" != "0" ]]; then
    echo "| WARN: unbound reload failed, trying to restart service..."
    supervisorctl restart unbound
    checkErr $? "Unbound service restart failed!"
  fi
fi
