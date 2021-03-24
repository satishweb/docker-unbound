IMAGE=satishweb/unbound
PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
WORKDIR=$(shell pwd)

ifdef PUSH
	EXTRA_BUILD_PARAMS = --push-images --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

all:
	TAGNAME=$$(${MAKE} latest-version) ;\
	./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${TAGNAME}" \
	  ${EXTRA_BUILD_PARAMS}

latest-version:
	@docker run --rm --entrypoint=sh alpine -c \
		"apk update >/dev/null 2>&1; apk info unbound" \
		|grep -e '^unbound-*.*description'\
		|awk '{print $$1}'\
		|sed -e 's/^[ \t]*//;s/[ \t]*$$//;s/ /-/g'\
		|sed $$'s/[^[:print:]\t]//g'\
		|sed 's/^unbound-//'
