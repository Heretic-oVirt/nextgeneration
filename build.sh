#!/bin/bash
# Script to prepare a HVP custom Fedora CoreOS automated installation ISO
# Note: tested on a Fedora Server 38 build machine to produce a Fedora CoreOS 38.xxx Live installation ISO
# Note: needs the following extra packages on the Fedora Server build machine: butane coreos-installer xorriso

build_version="2024042401"

echo "build script version ${build_version} starting"

# User-controlled variables
# Fedora CoreOS version/channel to install
ARCH="x86_64"
STREAM="stable"
VERSION="40.20240616.3.0"

# Self-derived variables
MAIN_VERSION=$(echo "${VERSION}" | sed -e 's/^\([^.]*\).*$/\1/')

# Get Fedora GPG keys and import them
if [ ! -s ./fedora-${MAIN_VERSION}.gpg ]; then
	curl -o ./fedora-${MAIN_VERSION}.gpg -C - https://fedoraproject.org/fedora.gpg
fi
gpg --import < ./fedora-${MAIN_VERSION}.gpg

# Get detached ISO signature
if [ ! -s ./fedora-coreos-${VERSION}-live.${ARCH}.iso.sig ]; then
	curl -O -C - https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds/${VERSION}/x86_64/fedora-coreos-${VERSION}-live.${ARCH}.iso.sig
fi

# Get and verify ISO image
while ! gpg --verify ./fedora-coreos-${VERSION}-live.${ARCH}.iso.sig ./fedora-coreos-${VERSION}-live.${ARCH}.iso > /dev/null 2>&1; do
	rm -f fedora-coreos-${VERSION}-live.${ARCH}.iso
	curl -O -C - https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds/${VERSION}/x86_64/fedora-coreos-${VERSION}-live.${ARCH}.iso
done

# Transpile the Ignition source for the Live installation environment
butane -d embedded-files -s -p -o /tmp/embedded.ign embedded.bu

# TODO: allow creation of PXE-based installation images

# Prepare a temporary file in a safe area for the ISO generation process
# Note: the coreos-installer command cannot overwrite an existing file - using the unsafe -u option as a workaround
tmp_file=$(mktemp -u)

# Embed the Ignition file into the Fedora CoreOS Live installation ISO image and make sure that kernel commandline arguments are sane
coreos-installer iso ignition embed -f -i /tmp/embedded.ign -o ${tmp_file} ./fedora-coreos-${VERSION}-live.${ARCH}.iso
coreos-installer iso kargs reset ${tmp_file}

# Prepare extra-files dir for the Live installation ISO
# Note: place any hvp_parameters*.sh and *.nmconnection files inside this dir to make them automatically available to the custom installation procedure
mkdir -p live-files

# Transpile the Ignition source for the installed environment
butane -d node-files -s -p -o live-files/node.ign node.bu

# Add extra dirs/files into the Fedora CoreOS Live installation ISO image created above
# Note: these files will be optionally used by the custom installation procedure (see embedded-files/post-install-hook.sh)
# Note: the following commandline options have been deduced using: xorriso -report_about warning -indev fedora-coreos-${VERSION}-live.${ARCH}.iso.sig -report_system_area as_mkisofs
xorriso -dev ${tmp_file} -pathspecs as_mkisofs -add live-files -- -as mkisofs -isohybrid-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"${tmp_file}" --mbr-force-bootable -iso_mbr_part_type 0x00 -c '/isolinux/boot.cat' -b '/isolinux/isolinux.bin' -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e '/images/efiboot.img' -no-emul-boot -boot-load-size 14116 -isohybrid-gpt-basdat

mv -f ${tmp_file} ./fedora-coreos-${VERSION}-live-hvp.${ARCH}.iso

# Remove generated artifacts
rm -f /tmp/embedded.ign live-files/node.ign
