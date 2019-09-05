PY_SRC_FILES=$(wildcard src/*.py)
SH_SRC_FILES=$(wildcard src/*.sh)
SRC_FILES=$(wildcard src/*.py) $(wildcard src/*.sh)
GIT_REV=$(shell git rev-parse HEAD)
TARBALL_URL=https://github.com/FIUS/drinklist-cli/archive/$(GIT_REV).tar.gz
TARBALL_SHA256SUM=$(shell curl -L "$(TARBALL_URL)" | sha256sum) # This is a hack, but tarballs sadly don't seem to be deterministic
VERSION=0.1
DEB_PACKAGE_NAME=packages/drinklist-cli_$(VERSION)-1

.PHONY: clean

all: packages/drinklist packages/PKGBUILD $(DEB_PACKAGE_NAME).deb

clean:
	rm -rf packages

packages/drinklist: $(SRC_FILES) # Builds a single standalone executable from the python files
	mkdir -p packages
	cp src/drink.py __main__.py
	zip drinklist.zip __main__.py $(filter-out src/drink.py, $(PY_SRC_FILES))
	echo "#!/usr/bin/env python3" > packages/drinklist
	cat drinklist.zip >> packages/drinklist
	chmod +x packages/drinklist
	rm __main__.py
	rm drinklist.zip

install: packages/drinklist
	mkdir -p $(DESTDIR)/usr/bin
	cp ./packages/drinklist $(DESTDIR)/usr/bin/drinklist
	echo '#!/bin/bash' > $(DESTDIR)/usr/bin/drink
	echo 'drinklist drink "$@"' >> $(DESTDIR)/usr/bin/drink
	chmod +x $(DESTDIR)/usr/bin/drink
	mkdir -p $(DESTDIR)/usr/share/bash-completion/completions
	cp ./src/bash_completions.sh $(DESTDIR)/usr/share/bash-completion/completions/drinklist
	cp ./src/bash_completions.sh $(DESTDIR)/usr/share/bash-completion/completions/drink

packages/PKGBUILD: package_templates/PKGBUILD.template $(SRC_FILES)
	mkdir -p packages
	sed "s|%%TARBALL_URL%%|$(TARBALL_URL)|;s|%%TARBALL_SHA256SUM%%|$(TARBALL_SHA256SUM)|" $< > $@

$(DEB_PACKAGE_NAME).deb: package_templates/DEBIAN_control.template packages/drinklist
	mkdir -p $(DEB_PACKAGE_NAME)/DEBIAN
	sed "s|%%VERSION%%|$(VERSION)|" $< > $(DEB_PACKAGE_NAME)/DEBIAN/control
	$(MAKE) install DESTDIR=$(DEB_PACKAGE_NAME)
	dpkg-deb --build $(DEB_PACKAGE_NAME)
	rm -rf $(DEB_PACKAGE_NAME)
