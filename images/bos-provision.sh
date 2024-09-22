#!/bin/sh
set -eu

dnf install -y epel-release dnf-plugins-core
dnf install -y "https://repos.openhpc.community/OpenHPC/3/EL_9/$(arch)/ohpc-release-3-1.el9.$(arch).rpm"
dnf config-manager --set-enabled crb
dnf copr enable cyqsimon/micro -y

rpm --import "https://www.elrepo.org/RPM-GPG-KEY-elrepo.org"
dnf install -y "https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm"

dnf update -y
dnf install -y --enablerepo=elrepo-kernel kernel-ml kernel-ml-modules kernel-ml-devel
dnf install -y --allowerasing --setopt=install_weak_deps=False \
    podman perl /bin/mailx ${PACKAGES}

dnf groupinstall 'Development Tools' --setopt=group_package_types=mandatory -y

dnf clean all

cat <<EOF >/etc/resolv.conf
# Overwritten at image build time, should be replaced by IPA
nameserver 1.1.1.1
EOF

fstrim -av

touch "/.autorelabel"
