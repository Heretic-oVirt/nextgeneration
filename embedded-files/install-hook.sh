#!/bin/bash
# Script to invoke the embedded Fedora CoreOS installer with custom pre/post actions and further parameters

inst_version="2024042101"

set -euo pipefail

echo "inst-hook script version ${inst_version} starting"

if [ -s /usr/local/bin/pre-install-hook ]; then
	source /usr/local/bin/pre-install-hook
else
	echo "Warning: custom pre-installation script not found - skipping pre-installation" 1>&2
fi

if [ -z "${nodeosdisk_device_name}" -o ! -b "/dev/${nodeosdisk_device_name}" ]; then
	echo "Fatal error: Ignition target disk variable not found or invalid (/dev/${nodeosdisk_device_name})" 1>&2
	exit 254
fi

if [ -z "${ign_source}" -o "${ign_fstype}" != "url" -a ! -s "${ign_source}" ]; then
	echo "Fatal error: custom Ignition file not found or invalid (${ign_source})" 1>&2
	exit 253
fi

if [ "${ign_fstype}" = "url" ]; then
	ign_option="--ignition-url"
else
	ign_option="--ignition-file"
fi

# Note: HVP hardcodes "metal" as platform in order to treat bare-metal and virtualized/cloud installations the same
/usr/bin/coreos-installer install ${ign_option} ${ign_source} --platform metal /dev/${nodeosdisk_device_name}

if [ -s /usr/local/bin/post-install-hook ]; then
	source /usr/local/bin/post-install-hook
else
	echo "Warning: custom post-installation script not found - skipping post-installation" 1>&2
fi

echo "inst-hook script version ${inst_version} exiting"
