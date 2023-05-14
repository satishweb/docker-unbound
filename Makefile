IMAGE=satishweb/unbound
PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
WORKDIR=$(shell pwd)
BASE_IMAGE=alpine:latest

UNBOUND_VERSION?=$(shell docker run --rm --entrypoint=sh ${BASE_IMAGE} -c \
					"apk update >/dev/null 2>&1; apk info unbound" \
					|grep -e '^unbound-*.*description'\
					|awk '{print $$1}'\
					|sed -e 's/^[ \t]*//;s/[ \t]*$$//;s/ /-/g'\
					|sed $$'s/[^[:print:]\t]//g'\
					|sed 's/^unbound-//')

# Set L to + for debug
L=@

test-env:
	echo "test-env: printing env values:"
	echo "Unbound Version: ${UNBOUND_VERSION}"

ifdef PUSH
	EXTRA_BUILD_PARAMS = --push-images --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

ifdef LOAD
	EXTRA_BUILD_PARAMS += --load
endif

all: build

build:
	/bin/bash ${BASH_FLAGS} ./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${UNBOUND_VERSION}" \
	  --extra-args "--build-arg UNBOUND_VERSION=${UNBOUND_VERSION}" \
	${EXTRA_BUILD_PARAMS}

test:
	docker build --build-arg UNBOUND_VERSION=${UNBOUND_VERSION} -t ${IMAGE}:${UNBOUND_VERSION} .
