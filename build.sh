#!/bin/bash
# Author: Satish Gaikwad <satish@satishweb.com>

## Functions

__usage() {
  if [[ "$1" != "" ]]; then
      echo "ERR: $1 "
  fi
  echo "Usage: $0
          -i|--image-name <DockerImageName>
          -p|--platforms <PlatformsList>
          -w|--work-dir <WorkDirPath>
          --push-images
          --push-git-tags
          -h|--help"
  echo "Description:"
  echo "  -i|--image-name : Name of the docker image."
  echo "    e.g. satishweb/imagename. (Def: current directory name)"
  echo "  -p|--platforms  : list of platforms to build for."
  echo "    (Def: linux/amd64,linux/arm64,linux/s390x,"
  echo "          linux/386,linux/arm/v7,linux/arm/v6)"
  echo "  -w|--work-dir   : Docker buildx command work dir path"
  echo "  --push-images   : Enables pushing of docker images to docker hub"
  echo "  --push-git-tags : Enabled push of git tags to git remote origin"
  echo "  -h|--help       : Prints this help menu"
  exit 1
}

__processParams() {
  while [ "$1" != "" ]; do
    case $1 in
      -i|--image-name) shift
                       [[ ! $1 ]] && __usage "Work dir path missing"
                       image="$1"
                       ;;
      -p|--platforms)  shift
                       [[ ! $1 ]] && __usage "Work dir path missing"
                       platforms="$1"
                       ;;
      -w|--work-dir)   shift
                       [[ ! $1 ]] && __usage "Work dir path missing"
                       workDir="$1"
                       ;;
      --push-images)   imgPush=yes
                       ;;
      --push-git-tags) tagPush=yes
                       ;;
      -h|--help)       __usage
                       ;;
      * )              __usage "Missing or incorrect parameters"
    esac
    shift
  done
  [[ ! $platforms ]] && \
  platforms="linux/amd64,linux/arm64,linux/s390x"
  platforms+=",linux/386,linux/arm/v7,linux/arm/v6"
  [[ ! $imgPush ]] && imgPush=no
  [[ ! $tagPush ]] && tagPush=no
  [[ ! $workDir ]] && workDir=$(pwd)
  [[ ! $image ]] && image=$(basename $(pwd))
}

__errCheck(){
  # $1 = errocode
  # $2 = msg
  [[ "$1" != "0" ]] && echo "ERR: $2" && exit $1
}

__dockerBuild(){
  # $1 = image name e.g. "satishweb/imagename"
  # $2 = image tags e.g. "latest 1.1.1"
  # $3 = platforms e.g. "linux/amd64,linux/arm64"
  # $4 = work dir path
  # $5 = Extra args for docker buildx command

  tagParams=""
  for i in $2; do tagParams+=" -t $1:$i"; done
  docker buildx build --platform "$3" $5 $tagParams $4
  __errCheck "$?" "Docker Build failed"
}

__validations() {
  ! [[ "$imgPush" =~ ^(yes|no)$ ]] && imgPush=no
  ! [[ "$tagPush" =~ ^(yes|no)$ ]] && tagPush=no

  # Check for buildx env
  if [[ "$(docker buildx ls\
           |grep -e " *default*.*running linux/amd64"\
           |wc -l\
          )" -lt "1" ]]; then
    __errCheck "1" "Docker buildx env is not setup, please fix it"
  fi
}

__checkSource() {
  # Lets do git pull if push is enabled
  if [[ "$imgPush" == "yes" ]]; then
    git checkout master >/dev/null 2>&1
    __errCheck "$?" "Git checkout to master branch failed..."
    git pull >/dev/null 2>&1
    __errCheck "$?" "Git pull for master branch failed..."
  fi
}

__setupDocker() {
  # Lets prepare docker image
  if [[ "$imgPush" == "yes" ]]; then
    echo "INFO: Logging in to Docker HUB... (Interactive Mode)"
    docker login
    __errCheck "$?" "Docker login failed..."
    extraDockerArgs=" --push"
  fi
  docker buildx create --name builder >/dev/null 2>&1
  docker buildx use builder >/dev/null 2>&1
  __errCheck "$?" "Could not use docker buildx default runner..."
}

__createGitTag() {
  # Lets create git tag and do push
  if [[ $verTag == *.*.* ]]
    then
      echo "INFO: Creating local git tag: $verTag"
      git tag -d $verTag >/dev/null 2>&1
      git tag $verTag >/dev/null 2>&1
      if [[ "$tagPush" == "yes" ]]; then
        echo "INFO: Pushing git tag to remote: $verTag"
        git push --delete origin $verTag >/dev/null 2>&1
        git push -f origin $verTag >/dev/null 2>&1
      fi
  else
    echo "WARN: Tag name is not valid, expected 3 digits: $verTag"
  fi
}

## Main
__processParams $@
__validations
__checkSource
__setupDocker

# Lets identify current unbound version and setup image tags
verTag="$(docker run --rm --entrypoint=sh alpine -c \
          "apk update >/dev/null 2>&1; apk info unbound"\
          |grep -e '^unbound-*.*description'\
          |awk -F '[- ]' '{print $2}'\
          |sed -e 's/^[ \t]*//;s/[ \t]*$//;s/ /-/g'\
          |sed $'s/[^[:print:]\t]//g'\
        )"
imageTags="latest $verTag"
echo "INFO: Building Docker Images (may take a while)"
echo "INFO: Docker image      : $image"
echo "INFO: Platforms         : $platforms"
echo "INFO: Docker image tags : $imageTags"
echo "INFO: Image tags push?  : $imgPush"
echo "INFO: Git tags          : $verTag"
echo "INFO: Git tags push?    : $tagPush"
__dockerBuild $image "$imageTags" "$platforms" "$workDir" "$extraDockerArgs"
__createGitTag
