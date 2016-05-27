TOPLEVEL ?= $(CURDIR)
COMMON ?= ~/COMMON
TARGET ?= meson8b-odroidc1

export ARCH=arm
export KBUILD:=${TOPLEVEL}/build/linux
export CROSS_COMPILE=arm-linux-gnueabi-
export INSTALL_MOD_PATH:=$(KBUILD)/rootfs

GIT_TAG ?= "master"
GIT_URL ?= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
GITCLONE = git clone --depth 1 --single-branch -b $(GIT_TAG)

all: vmlinux modules
	make -C $(KBUILD) modules_install
	tar -C $(INSTALL_MOD_PATH) -cJvf modules.tar.xz lib

defconfig:
$(KBUILD)/.config: $(COMMON)/linux
	mkdir -p $(KBUILD)
	make -C $(COMMON)/linux O=$(KBUILD) defconfig

vmlinux:	$(KBUILD)/.config
	make -C $(KBUILD) vmlinux dtbs -j12
	cp $(KBUILD)/vmlinux .
	$(CROSS_COMPILE)strip vmlinux
	cp `find $(KBUILD) -name $(TARGET).dtb` . 

modules:
	mkdir -p $(INSTALL_MOD_PATH)
	make -C $(KBUILD) modules -j12

clean:
	make -C $(COMMON)/linux mrproper
	rm -rf ${TOPLEVEL}/build
	rm -rf $(INSTALL_MOD_PATH)
	rm -f vmlinux *.dtb modules.tar.xz

$(COMMON)/linux:
	mkdir -p $(COMMON)
	cd $(COMMON) && $(GITCLONE) $(GITURL) linux
