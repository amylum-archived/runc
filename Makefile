PACKAGE = runc
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

.PHONY : default submodule build_container manual container build version push local

default: submodule build_container container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

build_container:
	docker build -t runc-pkg meta

container:
	./meta/launch

build: submodule
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/src/github.com/docker
	cp -R upstream $(BUILD_DIR)/src/github.com/opencontainers/runc
	export GOPATH=$(BUILD_DIR) && make -C $(BUILD_DIR)/src/github.com/opencontainers/runc
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp upstream/LICENSE $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	mkdir -p $(RELEASE_DIR)/usr/bin
	cp $(BUILD_DIR)/src/github.com/docker/containerd/bin/* $(RELEASE_DIR)/usr/bin/
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

