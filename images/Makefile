OPNSENSE_VERSION = 24.7
ALMA_VERSION = 9.5
ALMA_BUILD = 20241120

ALMA_VERSION_MAJOR := $(shell VERSION=$(ALMA_VERSION); echo $${VERSION%%.*})

.SECONDARY:
.DELETE_ON_ERROR:
.PHONY: all clean

all: opnsense.qcow2 \
	bos.x86_64.qcow2 bos.aarch64.qcow2 \
	cos.plain.x86_64.warewulf.tar  cos.plain.aarch64.warewulf.tar

clean: 
	rm -rf *.sha256 *.qcow2 *.iso *.iso.bz2 *.raw *.vmdk *.tar *.tmp.sh output-* .config .cache *.log


OPNsense-$(OPNSENSE_VERSION)-dvd-amd64.iso:
	wget https://pkg.opnsense.org/releases/mirror/$@.bz2 -O $@.bz2
	wget https://pkg.opnsense.org/releases/mirror/OPNsense-$(OPNSENSE_VERSION)-checksums-amd64.sha256 -O opnsense-checksums.sha256
	sha256sum -c opnsense-checksums.sha256 --ignore-missing
	bunzip2 $@.bz2
	rm -rf $@.bz2

opnsense.qcow2: export PACKER_LOG = 1
opnsense.qcow2: OPNsense-$(OPNSENSE_VERSION)-dvd-amd64.iso opnsense.pkr.hcl
	packer init .
	packer build -force -var "opnsense_image=$<" opnsense.pkr.hcl
	mv output-opnsense/opnsense.qcow2 opnsense.qcow2

### For BOS ###

PACKAGES = micro \
		   zsh \
		   wireguard-tools dnf-automatic systemd-oomd lsb-release cryptsetup firewalld qemu-guest-agent coreutils e2fsprogs \
		   java-17-openjdk-headless bash-completion git cmake wget curl rclone rsync \
		   ncurses-compat-libs htop lsof net-tools traceroute tcpdump iproute ethtool \
		   emacs-nox vim nano tree moreutils parallel tmux screen file which words ripgrep \
		   clinfo usbutils pciutils lm_sensors hwloc numactl psmisc ltrace strace perf valgrind

space := $(subst ,, )
comma := ,

AlmaLinux-$(ALMA_VERSION_MAJOR)-GenericCloud-$(ALMA_VERSION)-$(ALMA_BUILD).%.qcow2:
	wget https://repo.almalinux.org/almalinux/$(ALMA_BUILD)/cloud/$*/images/$@ -O $@
	wget https://repo.almalinux.org/almalinux/$(ALMA_BUILD)/cloud/$*/images/CHECKSUM -O bos-checksums.sha256
	sha256sum -c bos-checksums.sha256 --ignore-missing

AAVMF_CODE_PATH := $(firstword $(wildcard /usr/share/AAVMF/AAVMF_CODE*.fd))
AAVMF_VARS_PATH := $(firstword $(wildcard /usr/share/AAVMF/AAVMF_VARS*.fd))
OVMF_CODE_PATH := $(firstword $(wildcard /usr/share/OVMF/OVMF_CODE*.fd))
OVMF_VARS_PATH := $(firstword $(wildcard /usr/share/OVMF/OVMF_VARS*.fd))

bos.%.qcow2: export PACKER_LOG = 1
bos.%.qcow2: AlmaLinux-$(ALMA_VERSION_MAJOR)-GenericCloud-$(ALMA_VERSION)-$(ALMA_BUILD).%.qcow2 almalinux.pkr.hcl bos-provision.sh
	packer init . 
	packer build -force -only='bos.*' \
	  -var "name=bos" \
	  -var "image=$<" \
	  -var "arch=$*" \
	  -var "ovmf_code=$(OVMF_CODE_PATH)" -var "ovmf_vars=$(OVMF_VARS_PATH)" \
	  -var "aavmf_code=$(AAVMF_CODE_PATH)" -var "aavmf_vars=$(AAVMF_VARS_PATH)" \
	  -var "PACKAGES=$(PACKAGES)" \
	  almalinux.pkr.hcl
	mv output-bos."$*"/$@ "$@"

# Builds a warewulf uncompressed VNFS template of COS with warewulf patches
cos.%.warewulf.tar: Containerfile.cos.warewulf cos-provision.sh
	$(eval VARIANT := $(word 1,$(subst ., ,$*))) \
	$(eval ARCH := $(word 2,$(subst ., ,$*))) \
	podman build --security-opt label=disable --no-cache \
	  --build-arg PACKAGES="$(PACKAGES)" \
	  --build-arg VARIANT="$(VARIANT)" \
	  --build-arg COS_RELEASE="$(ALMA_VERSION)" \
	  --platform "linux/$(ARCH)" \
	  -f Containerfile.cos.warewulf -t "warewulf_cos_$*"
	podman save "warewulf_cos_$*" >"$@"
