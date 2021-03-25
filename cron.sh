#!/bin/bash
# Dirty cron script for automatically generating unbound latest image based on alpine unbound package release version

. /etc/profile
LOG_FILE=~/logs/unbound_cron.log
MAKE_LOG_FILE=~/logs/unbound_make.log
EMAIL_PROPERTIES=~/email.properties
FROM_EMAIL=$(cat ${EMAIL_PROPERTIES}|grep '^From='|awk -F '[=]' '{print $2}')
TO_EMAIL=$(cat ${EMAIL_PROPERTIES}|grep '^To='|awk -F '[=]' '{print $2}')

echo $(date) > ${LOG_FILE}

cd /opt/sources/docker-unbound

DOCKER_HUB_IMAGE=satishweb/unbound

CURRENT_UNBOUND_VERSION=$(docker run --rm --entrypoint=sh alpine -c "apk update >/dev/null 2>&1; apk info unbound"\
 |grep -e '^unbound-*.*description'\
 |awk -F '[- ]' '{print $2}'\
 |sed -e 's/^[ \t]*//;s/[ \t]*$//;s/ /-/g'\
 |sed $'s/[^[:print:]\t]//g')

echo "Current Version of Unbound in Alpine is: ${CURRENT_UNBOUND_VERSION}" >> ${LOG_FILE}

docker pull ${DOCKER_HUB_IMAGE} 2>&1 >/dev/null
IMAGE_ID=$(docker images|grep "${DOCKER_HUB_IMAGE}"|grep latest|awk '{print $3}')

CURRENT_IMAGE_TAG=$(/opt/sources/docker-script-find-latest-image-tag/docker_image_find_tag.sh -n ${DOCKER_HUB_IMAGE} -i ${IMAGE_ID} -f 1. -l 5|grep 'Found match. tag:'|awk -F '[:]' '{print $2}'| sed 's/ //g'|awk -F '[-]' '{print $1}')
echo "Current Version of Unbound Image is: ${CURRENT_IMAGE_TAG}" >> ${LOG_FILE}

if [[ "${CURRENT_IMAGE_TAG}" != "${CURRENT_UNBOUND_VERSION}" ]]; then
  echo "Unbound image version and current alpine unbound package version is different, we need to build new image and push" >> ${LOG_FILE}
  make all PUSH=yes LATEST=yes 2>&1 > ${MAKE_LOG_FILE}
  if [[ "$?" != "0" ]]; then
    echo "ERROR: Image build failed for unbound version ${CURRENT_UNBOUND_VERSION}"  >> ${LOG_FILE}
    mail -s "CRON: Unbound image build failed for: ${CURRENT_UNBOUND_VERSION}" -a "From: alerts@satishweb.com" satish@satishweb.com < ${LOG_FILE}
    exit 1
  else
    echo "INFO: image build successful, unbound version ${CURRENT_UNBOUND_VERSION}"  >> ${LOG_FILE}
    mail -s "CRON: Unbound new image: ${CURRENT_UNBOUND_VERSION}" -a "From: alerts@satishweb.com" satish@satishweb.com < ${LOG_FILE}
  fi
else
  echo "Unbound image version and current unbound version in alpine is same, no need to build image yet" >> ${LOG_FILE}
fi
