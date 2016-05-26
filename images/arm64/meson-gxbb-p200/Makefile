TOPLEVEL ?= $(CURDIR)
COMMON ?= ~/COMMON

export ARCH=arm64
export KBUILD:=${TOPLEVEL}/build/linux
export CROSS_COMPILE=aarch64-linux-gnu-
export INSTALL_MOD_PATH:=$(KBUILD)/rootfs

TAG ?= "master"

GITCLONE = git clone --depth 1 --single-branch -b $(TAG)

all: vmlinux modules
	make -C $(KBUILD) modules_install
	tar -C $(INSTALL_MOD_PATH) -cJvf modules.tar.xz lib

defconfig:
$(KBUILD)/.config: $(COMMON)/linux
	mkdir -p $(KBUILD)
	make -C $(COMMON)/linux O=$(KBUILD) ARCH=arm64 defconfig

vmlinux:	$(KBUILD)/.config
	make -C $(KBUILD) vmlinux dtbs -j12
	cp $(KBUILD)/vmlinux .
	$(CROSS_COMPILE)strip vmlinux
	cp `find $(KBUILD) -name meson-gxbb-p200.dtb` . 

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
	cd $(COMMON) && $(GITCLONE) git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
