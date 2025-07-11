#!/bin/bash
set -eu
# See https://github.com/warewulf/warewulf-node-images/blob/main/rockylinux-9/Containerfile-fixed

dnf install -y epel-release dnf-plugins-core
dnf install -y "https://repos.openhpc.community/OpenHPC/3/EL_9/$(arch)/ohpc-release-3-1.el9.$(arch).rpm"
dnf config-manager --set-enabled crb
dnf copr enable cyqsimon/micro -y

IFS='_' read -r -a values <<<"$VARIANT"
if [ ${#values[@]} -eq 0 ]; then
  echo "No variant specified"
  exit 1
fi

dnf update -y

for value in "${values[@]}"; do
  case $value in
  plain)
    dnf -y install kernel-core kernel-modules kernel-headers
    ;;
  el8)
    cat <<EOF >/etc/yum.repos.d/almalinux8.repo
[almalinux8-baseos]
name=AlmaLinux 8 BaseOS
baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/
enabled=0
gpgcheck=0
EOF
    dnf -y install kernel-core kernel-modules kernel-headers
    dnf --disablerepo="*" --enablerepo="almalinux8-baseos" -y downgrade kernel-core kernel-modules kernel-headers
    # shellcheck disable=SC2046
    rpm -ev $(rpm -qa | grep ^kernel | grep '\-5\.')
    rm -rf /usr/lib/modules/5.*
    ls /usr/lib/modules/
    ;;
  ml | lt)
    # ELRepo setup for ML kernel
    rpm --import "https://www.elrepo.org/RPM-GPG-KEY-elrepo.org"
    dnf install -y "https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm"
    dnf install -y --enablerepo=elrepo-kernel "kernel-$value" "kernel-$value-modules" "kernel-$value-devel"
    ;;
  cuda)
    case $(arch) in
    aarch64) nv_arch="sbsa" ;;
    *) nv_arch=$(arch) ;;
    esac
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/$nv_arch/cuda-rhel9.repo
    dnf module enable -y nvidia-driver:open-dkms
    dnf install -y nvidia-driver-cuda
    #dkms_autoinstaller isn't shipped in latest packages. Use `dkms autoinstall` instead.
    #ls /lib/modules | xargs -n1 /usr/lib/dkms/dkms_autoinstaller start
    for kver in $(ls /lib/modules); do
      dkms autoinstall -k "$kver"
    done
    dkms status
    systemctl enable nvidia-persistenced
    ;;
  rocm)
    case $(arch) in
    aarch64)
      echo "ROCm is not supported on aarch64"
      exit 1
      ;;
    esac

    tee /etc/yum.repos.d/amdgpu.repo <<EOF
[amdgpu]
name=amdgpu
baseurl=https://repo.radeon.com/amdgpu/6.2.1/el/9.4/main/x86_64/
enabled=1
priority=50
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF
    tee --append /etc/yum.repos.d/rocm.repo <<EOF
[ROCm-6.2.1]
name=ROCm6.2.1
baseurl=https://repo.radeon.com/rocm/el9/6.2.1/main
enabled=1
priority=50
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF
    dnf install -y amdgpu-dkms
    #ls /lib/modules | xargs -n1 /usr/lib/dkms/dkms_autoinstaller start
    for kver in $(ls /lib/modules); do
      dkms autoinstall -k "$kver"
    done
    dkms status
    dnf install -y libdrm-amdgpu

    # Remove the video group restriction
    cat <<EOF >/etc/udev/rules.d/99-kfd.rules
KERNEL=="kfd", MODE="0777"
EOF

    ;;
  nec)
    # TODO
    ;;
  *)
    echo "Unknown variant: $value"
    ;;
  esac
done

# shellcheck disable=SC2086
dnf install -y --allowerasing --setopt=install_weak_deps=False \
  ncurses-compat-libs sudo ohpc-slurm-client ipa-client \
  NetworkManager dhclient nfs-utils ipmitool openssh-clients openssh-server initscripts \
  ${PACKAGES}

dnf groupinstall 'Development Tools' --setopt=group_package_types=mandatory -y
dnf install -y gfortran

# Open up ports for slurm, NFS, SSH, and Wireguard
cat <<EOF >/etc/firewalld/zones/public.xml
<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Public</short>
  <description></description>
  <service name="ssh"/>
  <service name="dhcpv6-client"/>
  <service name="mountd"/>
  <service name="rpc-bind"/>

  <port port="60001-65000" protocol="tcp"/> <!-- Slurm srun -->
  <port port="6818" protocol="tcp"/> <!-- Slurmd -->
  <port port="51820" protocol="udp"/> <!-- Wireguard -->
  
  <forward/>
</zone>
EOF

cat <<EOF >/etc/resolv.conf
# Overwritten at image build time, should be replaced by IPA
nameserver 1.1.1.1
EOF

dnf clean all
