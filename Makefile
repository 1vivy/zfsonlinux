include /usr/share/dpkg/default.mk
# source form https://github.com/zfsonlinux/

PACKAGE = zfs-linux

SHA1 ?= zfs-2.2.0
SRCDIR = upstream
BUILDDIR ?= $(PACKAGE)-$(DEB_VERSION_UPSTREAM)
ORIG_SRC_TAR = $(PACKAGE)_$(DEB_VERSION_UPSTREAM).orig.tar.gz

ZFS_DEB1= libnvpair3linux_$(DEB_VERSION)_amd64.deb

ZFS_DEB_BINARY =				\
libpam-zfs_$(DEB_VERSION)_amd64.deb		\
libuutil3linux_$(DEB_VERSION)_amd64.deb		\
libzfs4linux_$(DEB_VERSION)_amd64.deb		\
libzfsbootenv1linux_$(DEB_VERSION)_amd64.deb	\
libzpool5linux_$(DEB_VERSION)_amd64.deb		\
zfs-test_$(DEB_VERSION)_amd64.deb			\
zfsutils-linux_$(DEB_VERSION)_amd64.deb		\
zfs-zed_$(DEB_VERSION)_amd64.deb

ZFS_DBG_DEBS = $(patsubst %_$(DEB_VERSION)_amd64.deb, %-dbgsym_$(DEB_VERSION)_amd64.deb, $(ZFS_DEB1) $(ZFS_DEB_BINARY))

ZFS_DEB2= $(ZFS_DEB_BINARY)			\
libzfslinux-dev_$(DEB_VERSION)_amd64.deb		\
python3-pyzfs_$(DEB_VERSION)_amd64.deb		\
pyzfs-doc_$(DEB_VERSION)_all.deb			\
spl_$(DEB_VERSION)_all.deb			\
zfs-initramfs_$(DEB_VERSION)_all.deb
DEBS= $(ZFS_DEB1) $(ZFS_DEB2) $(ZFS_DBG_DEBS)

ZFS_DSC = zfs-linux_$(DEB_VERSION).dsc

all: deb

.PHONY: deb dsc
deb: $(DEBS)

dsc:
	rm -rf *.dsc $(BUILDDIR)
	$(MAKE) $(ZFS_DSC)
	lintian $(ZFS_DSC)

# called from pve-kernel's Makefile to get patched sources
.PHONY: kernel
kernel: $(ZFS_DSC)
	dpkg-source -x $(ZFS_DSC) ../pkg-zfs
	$(MAKE) -C ../pkg-zfs -f debian/rules adapt_meta_file

.PHONY: dinstall
dinstall: $(DEBS)
	dpkg -i $(DEBS)

.PHONY: submodule
submodule:
	test -f "$(SRCDIR)/README.md" || git submodule update --init

$(SRCDIR)/README.md: clone-upstream

clone-upstream: submodule
	cd $(SRCDIR); git fetch; git reset --hard $(SHA1)

debian-changelog:
	rm -f debian/changelog
	VERSION=$$(awk -F': *' '/^Version:/ {print $$2}' $(SRCDIR)/META | tr -d ' '); \
	sed -e "s/@VER@/$$VERSION/g" -e "s|@SHA1@|$(SHA1)|g" \
		-e "s/@BUILDTIME@/$(shell date +"%a, %d %b %Y %T %z")/g" < debian/changelog.in > debian/changelog

.PHONY: zfs
zfs: $(DEBS)
$(ZFS_DEB2) $(ZFS_DBG_DEBS): $(ZFS_DEB1)
$(ZFS_DEB1): $(BUILDDIR)
	cd $(BUILDDIR); dpkg-buildpackage -b -uc -us
	lintian $(DEBS)

$(ORIG_SRC_TAR): $(BUILDDIR)
	tar czf $(ORIG_SRC_TAR) --exclude="$(BUILDDIR)/debian" $(BUILDDIR)

$(ZFS_DSC): $(BUILDDIR) $(ORIG_SRC_TAR)
	cd $(BUILDDIR); dpkg-buildpackage -S -uc -us -d

sbuild: $(ZFS_DSC)
	sbuild $(ZFS_DSC)

$(BUILDDIR): $(SRCDIR)/README.md $(SRCDIR) debian
	rm -rf $@ $@.tmp
	cp -a $(SRCDIR) $@.tmp
	cp -a debian $@.tmp/debian
	mv $@.tmp $@

.PHONY: clean
clean: 	
	rm -rf $(PACKAGE)-[0-9]*/
	rm -f *~ *.deb *.changes *.buildinfo *.build *.dsc *.orig.tar.* *.debian.tar.*

.PHONY: distclean
distclean: clean

.PHONY: upload
upload: UPLOAD_DIST ?= $(DEB_DISTRIBUTION)
upload: $(DEBS)
	tar -cf - $(DEBS) | ssh repoman@repo.proxmox.com -- upload --product pve,pmg,pbs --dist $(UPLOAD_DIST) --arch $(DEB_HOST_ARCH)
