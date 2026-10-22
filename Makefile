IMAGE=satishweb/unbound
IMAGE_TEST=satishweb/unbound-test
PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
DOCKER_BUILDX_CMD?=docker buildx
WORKDIR=$(shell pwd)

# The version of the unbound package that is installed. It has to match the
# version of the alpine release the image is built from. The build fails when
# it does not, so a change of the alpine release is noticed.
UNBOUND_VERSION?=1.25.2-r2
TAGNAME?=$(UNBOUND_VERSION)

# Set L to + for debug
L=@

# Build arguments passed to the docker build
BUILD_ARGS=--build-arg UNBOUND_VERSION=$(UNBOUND_VERSION)

ifdef PUSH
	EXTRA_BUILD_PARAMS += --push-images
endif

ifdef PUSH_GIT_TAGS
	EXTRA_BUILD_PARAMS += --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

ifdef NO_CACHE
	EXTRA_BUILD_PARAMS += --no-cache
endif

ifdef LOAD
	EXTRA_BUILD_PARAMS += --load
endif

all: build

build:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${TAGNAME}" \
	  --docker-file "Dockerfile" \
	  --docker-buildx-cmd "${DOCKER_BUILDX_CMD}" \
	  $(BUILD_ARGS) \
	  ${EXTRA_BUILD_PARAMS}

test:
	$(L)docker build -t ${IMAGE_TEST}:${TAGNAME} .
	$(L)${MAKE} run-tests

run-tests:
	$(L)cd tests; pipenv install --python 3.12
	$(L)cd tests; pipenv run python ./test-unbound-server.py --image ${IMAGE_TEST}:${TAGNAME}

# Commands:
#   make test # Build the image for the local platform and run the tests
#   make all # Build the image for all the platforms
#   make all LATEST=true PUSH=true PUSH_GIT_TAGS=true # Build, push the images and push the git tags
