#!/bin/bash
# Author: Satish Gaikwad <satish@satishweb.com>
# For manual push to docker hub, pass "manual" as 2nd parameter to this script

##############
## INIT
##############
sDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
image="satishweb/unbound"

# Get params
buildType=$1
imgPush=$2

##############
## Functions
##############

# Usage function
usage() {
  echo "Usage: $0 <BuildType> <ImagePush> "
  echo "      BuildType: amd64|arm  -- Optional (Def: amd64)"
  echo "      ImagePush: manual|auto -- Optional (Def: auto)"
  exit 1
}

# lets display usage and exit here if first parameter is help
[[ "$1" == "help" ]] && usage

# error check function
errCheck(){
  # $1 = errocode
  # $2 = msg
  # $3 = exit on fail
  if [ "$?" != "0" ]
    then
      echo "ERR| $2"
      # if $3 is set then exit with errorcode
      [[ $3 ]] && exit $1
  fi
}

# Docker Build function
dockerBuild(){
  # $1 = image type

  # Lets set appropriate tags based on buildType
  imageTag=${1}-latest
  dockerfile=Dockerfile_$1
  echo "INFO: Building $1 Image: $image:$imageTag ... (may take a while)"
  docker build . -f $dockerfile -t $image:$imageTag
  errCheck "$?" "Docker Build failed" "exitOnFail"
  
  # Lets identify unbound version and setup image tags
  unboundVer="$(docker run --rm -it --entrypoint=bash $image:$imageTag -c "unbound -h"|grep -e '^Version '|awk '{print $2}'|sed $'s/[^[:print:]\t]//g')"

  # Lets set unbound image version tag based on buildType
  verTag=${1}-$unboundVer
 
  if [[ $unboundVer == *.*.* ]]
    then
      echo "INFO: Creating tags..."
      docker tag $image:$imageTag $image:$verTag >/dev/null 2>&1
      errCheck "$?" "Tag creation failed"
    else
      echo "WARN: Could not determine awscli version, ignoring tagging..."
  fi

  # Lets create git tag and do checkin
  if [[ $unboundVer == *.*.* ]]
    then
      echo "INFO: Creating/Updating git tag"
      git tag -d $verTag
      git push --delete origin $verTag
      git tag $verTag
      git push origin --tags
  fi
}

##############
## Validations
##############

! [[ "$buildType" =~ ^(amd64|arm)$ ]] && buildType=amd64
! [[ "$imgPush" =~ ^(manual|auto)$ ]] && imgPush=auto

##############
## Main method
##############

# Head
echo "INFO: Build Type: $buildType"
echo "INFO: Image Push $imgPush"
echo "NOTE: Execute \"$0 help\" to know parameters list"
echo "------------------------------------------------"
# Lets do git pull
echo "INFO: Fetching latest codebase changes"
git checkout master
git pull 

# Lets prepare docker image
echo "INFO: Removing all tags of image $image ..."
#docker rmi -f $(docker images|grep "$image"|awk '{print $1":"$2}') >/dev/null 2>&1
dockerBuild $buildType

# Lets do manual push to docker.
# To be used only if docker automated build process is failed
if [[ "$imgPush" == "manual" ]]
  then
    echo "INFO: Logging in to Docker HUB... (Interactive Mode)"
    docker login
    errCheck "$?" "Docker login failed..." "exitOnFail"
    echo "INFO: Pushing build to Docker HUB..."
    docker push $image
    errCheck "$?" "Docker push failed..." "exitOnFail"
fi
