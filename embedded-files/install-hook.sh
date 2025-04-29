#!/bin/bash
# Script to invoke the embedded Fedora CoreOS installer with custom pre/post actions and further parameters

inst_version="2025010601"

# Note: any non-zero exit code immediately terminates this script and puts the whole installation system in emergency mode
set -euo pipefail

echo "inst-hook script version ${inst_version} starting"

# Load the pre-install hook script
# Note: it is assumed that the pre-install hook script will define the following variables:
# pre_version
# local_igncfg_cache
# given_ign_source
# ign_fstype
# ign_dev
# nodeosdisk_device_name
# localst_actual_vg_name
# replicatedst_actual_disk_name
# given_timezone
# given_kblayout
# given_domainname
# given_hostname
# given_persistnmconf
# given_nameservers
# given_ntpservers
# gateway_address
# main_interface
# assigned_ipaddr
# network_prefix
# first_address
# addresses_to_try
# given_removepkgs
# given_replacepkgs
# given_addpkgs
# given_removekargs
# given_replacekargs
# given_addkargs
# given_masksvcs
# given_disablesvcs
# given_enablesvcs
if [ -s /usr/local/bin/pre-install-hook ]; then
	source /usr/local/bin/pre-install-hook
else
	echo "Warning: custom pre-installation script not found - skipping pre-installation" 1>&2
fi

# Check target installation disk
if [ -z "${nodeosdisk_device_name}" -o ! -b "/dev/${nodeosdisk_device_name}" ]; then
	echo "Fatal error: Ignition target disk variable not found or invalid (/dev/${nodeosdisk_device_name})" 1>&2
	exit 254
fi

# Check Ignition file
# Note: it is assumed that the pre-install hook script will make the custom Ignition file locally available under /tmp/igncfg-pre
if [ -z "${given_ign_source}" -o ! -s /tmp/igncfg-pre/$(basename "${given_ign_source}") ]; then
	echo "Fatal error: custom Ignition file not found or invalid (/tmp/igncfg-pre/$(basename ${given_ign_source}))" 1>&2
	exit 253
fi

# Note: hardcoding "metal" as platform in order to treat bare-metal and virtualized/cloud installations the same
/usr/bin/coreos-installer install --ignition-file /tmp/igncfg-pre/$(basename ${given_ign_source}) --platform metal /dev/${nodeosdisk_device_name}

# Load the post-install hook script
# Note: it is assumed that the post-install hook script will define the following additional variables:
# post_version
# ostree_path
if [ -s /usr/local/bin/post-install-hook ]; then
	source /usr/local/bin/post-install-hook
else
	echo "Warning: custom post-installation script not found - skipping post-installation" 1>&2
fi

echo "inst-hook script version ${inst_version} exiting"

