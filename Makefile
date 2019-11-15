IMAGE=satishweb/unbound
PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
WORKDIR=$(shell pwd)
ifdef PUSH
	EXTRA_BUILD_PARAMS=--push-images --push-git-tags
endif

all:
	./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  ${EXTRA_BUILD_PARAMS}
