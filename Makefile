IMAGE=satishweb/unbound
PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
WORKDIR=$(shell pwd)
TAGNAME?=devel

# Set L to + for debug
L=@

UBUNTU_IMAGE=ubuntu:20.04
ALPINE_IMAGE=alpine:latest

ifdef PUSH
	EXTRA_BUILD_PARAMS = --push-images --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

all:
	$(L)TAGNAME=$$(docker run --rm --entrypoint=sh ${ALPINE_IMAGE} -c \
		"apk update >/dev/null 2>&1; apk info unbound" \
		|grep -e '^unbound-*.*description'\
		|awk '{print $$1}'\
		|sed -e 's/^[ \t]*//;s/[ \t]*$$//;s/ /-/g'\
		|sed $$'s/[^[:print:]\t]//g'\
		|sed 's/^unbound-//' \
		|cut -d '-' -f 1) ;\
	${MAKE} build-alpine build-ubuntu TAGNAME=$$TAGNAME
	$(L)TAGNAME=$$(docker run --rm --entrypoint=bash ${UBUNTU_IMAGE} -c \
		"cat /etc/apt/sources.list|grep -e '.*deb http.*-security universe' > /etc/apt/sources.list.d/security.list && \
		truncate --size 0 /etc/apt/sources.list && \
		apt update -yqq>/dev/null 2>&1 && \
		apt-get update -yqq >/dev/null 2>&1 && \
		apt-cache madison unbound \
		|head -1 \
		|cut -d \| -f 2 \
		|sed 's/ //g' \
		|cut -d '-' -f 1") ;\
	${MAKE} build-ubuntu TAGNAME=$$TAGNAME

build-alpine:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "alpine-${TAGNAME}" \
	  --docker-file "Dockerfile.alpine" \
	  ${EXTRA_BUILD_PARAMS}

build-ubuntu:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "ubuntu-${TAGNAME}" \
	  --docker-file "Dockerfile.ubuntu" \
	  ${EXTRA_BUILD_PARAMS} --mark-latest=no

test:
	$(L)docker build -t ${IMAGE}:${TAGNAME} .

show-version:
	$(L)echo -n "Latest unbound version in alpine repo is: "
	$(L)docker pull ${ALPINE_IMAGE} >/dev/null 2>&1
	$(L)docker run --rm --entrypoint=sh ${ALPINE_IMAGE} -c \
		"apk update >/dev/null 2>&1; apk info unbound" \
		|grep -e '^unbound-*.*description'\
		|awk '{print $$1}'\
		|sed -e 's/^[ \t]*//;s/[ \t]*$$//;s/ /-/g'\
		|sed $$'s/[^[:print:]\t]//g'\
		|sed 's/^unbound-//' \
		|cut -d '-' -f 1
	$(L)echo -n "Latest unbound version in ubuntu repo is: "
	$(L)docker pull ${UBUNTU_IMAGE} >/dev/null 2>&1
	$(L)docker run --rm --entrypoint=bash ${UBUNTU_IMAGE} -c \
		"cat /etc/apt/sources.list|grep -e '.*deb http.*-security universe' > /etc/apt/sources.list.d/security.list && \
		truncate --size 0 /etc/apt/sources.list && \
		apt update -yqq>/dev/null 2>&1 && \
		apt-get update -yqq >/dev/null 2>&1 && \
		apt-cache madison unbound \
		|head -1 \
		|cut -d \| -f 2 \
		|sed 's/ //g' \
		|cut -d '-' -f 1"
