#!/bin/bash
# Script to prepare a HVP custom Fedora CoreOS automated installation ISO
# Note: tested on a Fedora Server 40 build machine to produce a Fedora CoreOS 40.xxx Live installation ISO
# Note: besides base utils, this script needs the following packages on the Fedora Server build machine: butane coreos-installer xorriso
# Note: to set custom installation architecture add hvp_arch=XXXX where XXXX is the installation architecture (default being the architecture of the image-building machine)
# Note: to set custom installation stream add hvp_stream=XXXX where XXXX is one of stable*, testing, next
# Note: to set custom installation version add hvp_version=XXXX where XXXX is the installation version (default being 40.20241019.3.0)
# Note: to set custom installation admin username add hvp_instadminname=myadmin where myadmin is the installation admin username (default being instadmin)
# Note: to set custom installation admin password add hvp_instadminpwd=myothersecret where myothersecret is the SHA512 hash of the installation admin user password (default being the SHA512 hash of hvpdemo)
# Note: to set custom installation admin SSH public key add hvp_instadminsshpubkey=mysshpubkey where mysshpubkey is the SSH public key which will allow SSH login as the installation admin user (default being a custom development SSH public key)
# Note: to set custom installation root password add hvp_instrootpwd=myothersecret where myothersecret is the SHA512 hash of the installation root user password (default being the SHA512 hash of HVP_dem0)

build_version="2024113001"

echo "build script version ${build_version} starting"

# Load defaults
defaults_file="live-files/hvp_parameters.sh"
if [ -s "${defaults_file}" ]; then
	bash -n "${defaults_file}" > /dev/null 2>&1
	res=$?
	if [ ${res} -ne 0 ]; then
		# Report invalid configuration fragment and skip it
		echo "Skipping invalid configuration fragment ${defaults_file}" 1>&2
		continue
	fi
	echo "Loading configuration fragment ${defaults_file}" 1>&2
	source "./${defaults_file}"
fi

# User-controlled variables

# Detect Fedora CoreOS architecture to install
given_arch=$(echo "$*" | sed -n -e 's/^.*hvp_arch=\(\S*\).*$/\1/p')
# No indication on architecture: use default choice
if [ -z "${given_arch}" ]; then
	if [ -n "${default_arch}" ]; then
		given_arch="${default_arch}"
	else
		given_arch=$(uname -m)
	fi
fi

# Detect Fedora CoreOS channel to install
given_stream=$(echo "$*" | sed -n -e 's/^.*hvp_stream=\(\S*\).*$/\1/p')
# No indication on channel: use default choice
if [ -z "${given_stream}" ]; then
	if [ -n "${default_stream}" ]; then
		given_stream="${default_stream}"
	else
		given_stream="stable"
	fi
fi

# Detect Fedora CoreOS version to install
# TODO: autodetect latest version by parsing https://builds.coreos.fedoraproject.org/prod/streams/${given_stream}/releases.json
given_version=$(echo "$*" | sed -n -e 's/^.*hvp_version=\(\S*\).*$/\1/p')
# No indication on version: use default choice
if [ -z "${given_version}" ]; then
	if [ -n "${default_version}" ]; then
		given_version="${default_version}"
	else
		given_version="40.20241019.3.0"
	fi
fi

# Determine installation admin username, password hash and SSH public key
given_instadmin_username="$(echo "$*" | sed -n -e 's/^.*hvp_instadminname=\(\S*\).*$/\1/p')"
if [ -z "${given_instadmin_username}" ]; then
	if [ -n "${default_instadmin_username}" ]; then
		given_instadmin_username="${default_instadmin_username}"
	else
		given_instadmin_username="instadmin"
	fi
fi
given_instadmin_password="$(echo "$*" | sed -n -e 's/^.*hvp_instadminpwd=\(\S*\).*$/\1/p')"
if [ -z "${given_instadmin_password}" ]; then
	if [ -n "${default_instadmin_password}" ]; then
		given_instadmin_password="${default_instadmin_password}"
	else
		given_instadmin_password='$6$EngnSSn5$DiapvymRZ579Tt6pNBgRwT7D7PTDzWkT3ffKUO1U1qMloraFsg7jI6WfdM1oddxDvW9AFmBMKNOG1ylW7KiFU.'
	fi
fi
given_instadmin_sshpubkey="$(echo "$*" | sed -n -e 's/^.*hvp_instadminsshpubkey=\(\S*\).*$/\1/p')"
if [ -z "${given_instadmin_sshpubkey}" ]; then
	if [ -n "${default_instadmin_sshpubkey}" ]; then
		given_instadmin_sshpubkey="${default_instadmin_sshpubkey}"
	else
		given_instadmin_sshpubkey='ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBABuG9cJmQajdDokyk0C/v2bla9Z5TPJTBU0iLVQMyyUbvP+NHb0TKN3Mwex+M0bPA+LVEbgj+6gWw+yf/8CR3p3hACiiEu4qgFihXJdP69DBCv2zU/noDj6xN08m3+P9iwK/YdxQ4q2EpAqVX7B+r1sYypttXrUF64R0vLXoz6+WtQOdQ== root@twilight.mgmt.private'
	fi
fi

# Determine installation root password hash
given_instroot_password="$(echo "$*" | sed -n -e 's/^.*hvp_instrootpwd=\(\S*\).*$/\1/p')"
if [ -z "${given_instroot_password}" ]; then
	if [ -n "${default_instroot_password}" ]; then
		given_instroot_password="${default_instroot_password}"
	else
		given_instroot_password='$6$EngnSSn5$DiapvymRZ579Tt6pNBgRwT7D7PTDzWkT3ffKUO1U1qMloraFsg7jI6WfdM1oddxDvW9AFmBMKNOG1ylW7KiFU.'
	fi
fi

# Self-derived variables
main_version=$(echo "${given_version}" | sed -e 's/^\([^.]*\).*$/\1/')

# Get Fedora GPG keys and import them
if [ ! -s ./fedora-${main_version}.gpg ]; then
	curl -o ./fedora-${main_version}.gpg -C - https://fedoraproject.org/fedora.gpg
fi
gpg --import < ./fedora-${main_version}.gpg

# Get detached ISO signature
if [ ! -s ./fedora-coreos-${given_version}-live.${given_arch}.iso.sig ]; then
	curl -O -C - https://builds.coreos.fedoraproject.org/prod/streams/${given_stream}/builds/${given_version}/x86_64/fedora-coreos-${given_version}-live.${given_arch}.iso.sig
fi

# Get and verify ISO image
while ! gpg --verify ./fedora-coreos-${given_version}-live.${given_arch}.iso.sig ./fedora-coreos-${given_version}-live.${given_arch}.iso > /dev/null 2>&1; do
	rm -f fedora-coreos-${given_version}-live.${given_arch}.iso
	curl -O -C - https://builds.coreos.fedoraproject.org/prod/streams/${given_stream}/builds/${given_version}/x86_64/fedora-coreos-${given_version}-live.${given_arch}.iso
done

# Prepare temporary files in a safe area for the installation-environment Ignition file generation
tmp_embedded_bu_file=$(mktemp)
tmp_embedded_ign_file=$(mktemp)

# Specialize the Ignition source for the Live installation environment
# Note: performing escape on password hash and SSH public key
/usr/bin/sed \
	-e "s/__HVP_INSTADMIN_USERNAME_HVP__/${given_instadmin_username}/g" \
	-e "s/__HVP_INSTADMIN_PASSWORD_HASH_HVP__/$(echo "${given_instadmin_password}" | sed -e 's/[&/\]/\\&/g')/g" \
	-e "s/__HVP_INSTADMIN_SSH_PUBKEY_HVP__/$(echo "${given_instadmin_sshpubkey}" | sed -e 's/[&/\]/\\&/g')/g" \
	-e "s/__HVP_INSTROOT_PASSWORD_HASH_HVP__/$(echo "${given_instroot_password}" | sed -e 's/[&/\]/\\&/g')/g" \
embedded.bu > ${tmp_embedded_bu_file}

# Transpile the Ignition source for the Live installation environment
butane -d embedded-files -s -p -o ${tmp_embedded_ign_file} ${tmp_embedded_bu_file}

# TODO: allow creation of PXE-based installation images

# Prepare a temporary file in a safe area for the ISO generation process
# Note: the coreos-installer command cannot overwrite an existing file - using the unsafe -u option as a workaround
tmp_iso_file=$(mktemp -u)

# Embed the Ignition file into the Fedora CoreOS Live installation ISO image and make sure that kernel commandline arguments are sane
coreos-installer iso ignition embed -f -i ${tmp_embedded_ign_file} -o ${tmp_iso_file} ./fedora-coreos-${given_version}-live.${given_arch}.iso
coreos-installer iso kargs reset ${tmp_iso_file}

# Prepare extra-files dir for the Live installation ISO
# Note: place any hvp_parameters*.sh and *.nmconnection files inside this dir to make them automatically available to the custom installation procedure
mkdir -p live-files

# Transpile the Ignition source for the installed environment
butane -d node-files -s -p -o live-files/node.ign node.bu

# Add extra dirs/files into the Fedora CoreOS Live installation ISO image created above
# Note: these files will be optionally used by the custom installation procedure (see embedded-files/{{pre,post}-,}install-hook.sh)
# Note: the following commandline options have been deduced using: xorriso -report_about warning -indev fedora-coreos-${given_version}-live.${given_arch}.iso.sig -report_system_area as_mkisofs
xorriso -dev ${tmp_iso_file} -pathspecs as_mkisofs -add live-files -- -as mkisofs -isohybrid-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"${tmp_iso_file}" --mbr-force-bootable -iso_mbr_part_type 0x00 -c '/isolinux/boot.cat' -b '/isolinux/isolinux.bin' -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e '/images/efiboot.img' -no-emul-boot -boot-load-size 14116 -isohybrid-gpt-basdat

mv -f ${tmp_iso_file} ./fedora-coreos-${given_version}-live-hvp.${given_arch}.iso

# Remove generated artifacts
rm -f ${tmp_embedded_bu_file} ${tmp_embedded_ign_file} live-files/node.ign

echo "build script version ${build_version} exiting"
