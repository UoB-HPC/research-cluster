#!/bin/bash

set -eu

extract_wwclient_for_arch() {
    local arch="$1"
    local dest="$2"

    mkdir -p "$dest"
    wd="$(mktemp -d)"
    (
        cd "$wd"
        dnf download "warewulf-ohpc.$arch"
        rpm2cpio warewulf-ohpc*."$arch".rpm | cpio -idm

        # warewulf-ohpc >= 4.5.0 has an extra rootfs/ segment in the wwclient path
        for src in \
            "./srv/warewulf/overlays/wwinit/warewulf/wwclient" \
            "./srv/warewulf/overlays/wwinit/rootfs/warewulf/wwclient"; do
            if [[ -e "$src" ]]; then
                cp "$src" "$dest/wwclient"
                file "$dest/wwclient"
                break
            fi
        done || {
            echo "Error: wwclient not found in any expected paths." >&2
            exit 1
        }
    )
    rm -rf "$wd"
}

arch="$1"
extract_wwclient_for_arch "$arch" "/srv/warewulf/overlays/arch-$arch/warewulf"
wwctl overlay build
