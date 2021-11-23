SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

UBI_IMAGE ?= registry.access.redhat.com/ubi8/ubi-minimal:latest
GOLANG_VERSION ?= v1.16.10b7-multiarch
BUILD_META ?= -multiarch-build$(shell date +%Y%m%d)
KUBERNETES_VERSION ?= v1.22.4-rke2r1-build20211123
ORG ?= rancher
PKG ?= github.com/kubernetes/dns
SRC ?= github.com/kubernetes/dns
TAG ?= 1.21.2$(BUILD_META)

ifneq ($(DRONE_TAG),)
TAG := $(DRONE_TAG)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker build \
                --build-arg ARCH=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg ARCH=$(ARCH) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
                --build-arg KUBERNETES=$(ORG)/hardened-kubernetes:$(KUBERNETES_VERSION) \
                --build-arg GO_IMAGE=$(ORG)/hardened-build-base:$(GOLANG_VERSION) \
                --build-arg UBI_IMAGE=$(UBI_IMAGE) \
		--tag $(ORG)/hardened-dns-node-cache:$(TAG) \
		--tag $(ORG)/hardened-dns-node-cache:$(TAG)-$(ARCH) \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-dns-node-cache:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-dns-node-cache:$(TAG) \
		$(ORG)/hardened-dns-node-cache:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-dns-node-cache:$(TAG)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIESdnsNodeCache) --no-progress --ignore-unfixed $(ORG)/hardened-dns-node-cache:$(TAG)

