# Script sourced immediately before the embedded Fedora CoreOS installer invocation is initiated
# Note: to influence disk wiping logic add hvp_diskwiping=XXX where XXX is one of none, all, os, extra, used*
# Note: to influence selection of the target disk for node OS installation add hvp_nodeosdisk=AAA where AAA is either the device name (sda, sdb ecc) or one of first, last, smallest*, last-smallest
# Note: to influence selection of the target disk for node-local storage add hvp_localstdisk=BBB where BBB is either the device name (sda, sdb ecc) or one of skip, largest*, smallest
# Note: to influence selection of the target disk for replicated storage add hvp_replicatedstdisk=CCC where CCC is either the device name (sda, sdb ecc) or one of skip, largest, smallest*

pre_version="2024070903"

echo "pre-hook script version ${pre_version} starting"

# Note: Hardcoded defaults are kept inside /etc/sysconfig/custom-install and propagated as environment variables through systemd

# A simplistic regex matching IP addresses
# TODO: use a complete/correct regex (verifying that it works with the grep version in use)
IPregex='[0-9]*[.][0-9]*[.][0-9]*[.][0-9]*'

# Detect any configuration fragments and load them into the installation environment
# Note: only embedded/HTTP/HTTPS/TFTP methods are supported
# TODO: support also S3, ABFS and GS
mkdir -p /tmp/igncfg-pre
ign_source="$(cat /proc/cmdline | sed -n -e 's/^.*\s*coreos\.inst\.ignition_url=\(\S*\)\s*.*$/\1/p')"
if [ -z "${ign_source}" ]; then
	# Note: if we are here and no Ignition URL has been explicitly specified, then it must have been embedded into the ISO
	ign_source="${embedded_ign_source}"
fi
if [ -n "${ign_source}" ]; then
	ign_dev=""
	if echo "${ign_source}" | grep -q "^${embedded_ign_source}" ; then
		# Note: blindly assuming an embedded subfolder on a custom ISO image
		ign_host="localhost"
		ign_dev="$(dirname ${embedded_ign_source})"
		ign_fstype="filesystem"
	elif echo "${ign_source}" | grep -Eq '^(http|https|tftp):' ; then
		# Note: blindly extracting URL from kernel commandline
		ign_host="$(echo ${ign_source} | sed -e 's%^.*//%%' -e 's%/.*$%%')"
		ign_dev="$(echo ${ign_source} | sed -e 's%/[^/]*$%%')"
		ign_fstype="url"
	else
		echo "Unsupported Ignition source detected" 1>&2
	fi
	if [ -z "${ign_dev}" ]; then
		echo "Unable to extract Ignition source - skipping configuration fragments retrieval" 1>&2
	else
		# Note: for network-based Ignition file retrieval methods we extract the relevant nic MAC address to get the machine-specific fragment
		pushd /tmp/igncfg-pre
		if [ "${ign_fstype}" = "url" ]; then
			# Note: we detect the nic device name as the one detaining the route towards the host holding the Ignition file
			# Note: regarding the Ignition file host: we assume that if it has not already been given as an IP address then it is assumed to be a DNS FQDN
			if ! echo "${ign_host}" | grep -q "${IPregex}" ; then
				ign_host_ip=$(dig "${ign_host}" A +short | head -1)
			else
				ign_host_ip="${ign_host}"
			fi
			ign_nic=$(ip route get "${ign_host_ip}" | sed -n -e 's/^.*\s\+dev\s\+\(\S\+\)\s\+.*$/\1/p')
			if [ -f "/sys/class/net/${ign_nic}/address" ]; then
				ign_mac=$(sed -e 's/:-//g' /sys/class/net/${ign_nic}/address)
				ign_custom_frags="${ign_custom_frags} hvp_parameters_${ign_mac}.sh"
			fi
			for custom_frag in ${ign_custom_frags} ; do
				echo "Attempting network retrieval of configuration fragment ${ign_dev}/${custom_frag}" 1>&2
				curl -O -C - "${ign_dev}/${custom_frag}"  || true
			done
		else
			# Note: filesystem-based Ignition file retrieval autodetected
			for custom_frag in ${ign_custom_frags} ; do
				echo "Attempting filesystem retrieval of configuration fragment ${custom_frag}" 1>&2
				if [ -f "${ign_dev}/${custom_frag}" ]; then
					cp "${ign_dev}/${custom_frag}" .
				fi
			done
		fi
		popd
	fi
fi
# Load any configuration fragment found, in the proper order
# Note: configuration-fragment defaults will override hardcoded defaults
# Note: commandline parameters will override configuration-fragment and hardcoded defaults
# Note: configuration fragments get executed with full privileges and no further controls beside a bare syntax check: obvious security implications must be taken care of (use HTTPS on a private network for network-retrieved Ignition file and fragments)
pushd /tmp/igncfg-pre
for custom_frag in ${ign_custom_frags} ; do
	if [ -f "${custom_frag}" ]; then
		# Perform a configuration fragment sanity check before loading
		res=0
		bash -n "${custom_frag}" > /dev/null 2>&1 || res=1
		if [ ${res} -ne 0 ]; then
			# Report invalid configuration fragment and skip it
			echo "Skipping invalid configuration fragment ${custom_frag}" 1>&2
			continue
		fi
		echo "Loading configuration fragment ${custom_frag}" 1>&2
		source "./${custom_frag}"
	fi
done
popd

# Invoke custom pre-install actions if defined
# Note: the pre_install_hook_custom_actions function must have been defined by means of the dynamically retrieved configuration fragments
pre_install_hook_custom_actions || true

# Find the storage devices
# Note: we want the device list alphabetically ordered anyway
all_st_devices="$(lsblk -d -r -n -o NAME | grep -Ev '^(loop|fd|sr)[[:digit:]]*[[:space:]]*' | awk '{print $1}' | sort)"
# Note: we assume that all suitable devices are available for use
available_st_devices="${all_st_devices}"

# Determine node OS disk choice
given_nodeosdisk=$(sed -n -e 's/^.*hvp_nodeosdisk=\(\S*\).*$/\1/p' /proc/cmdline)
# No indication on node OS disk choice: use default choice
if [ -z "${given_nodeosdisk}" ]; then
	given_nodeosdisk="${default_nodeosdisk}"
fi
if [ -b "/dev/${given_nodeosdisk}" ]; then
	# If the given string is a device name then use that
	nodeosdisk_device_name="${given_nodeosdisk}"
	nodeosdisk_device_size=$(blockdev --getsize64 "/dev/${nodeosdisk_device_name}")
else
	# If the given string is a generic indication then find the proper device
	case "${given_nodeosdisk}" in
		first)
			nodeosdisk_device_name=$(echo "${available_st_devices}" | head -1)
			nodeosdisk_device_size=$(blockdev --getsize64 "/dev/${nodeosdisk_device_name}")
			;;
		last)
			nodeosdisk_device_name=$(echo "${available_st_devices}" | tail -1)
			nodeosdisk_device_size=$(blockdev --getsize64 "/dev/${nodeosdisk_device_name}")
			;;
		*)
			# Note: we allow for choosing either the first smallest device (default, if only "smallest" has been indicated) or the last one
			case "${given_nodeosdisk}" in
				last-smallest)
					# If we want the last of the smallests then keep changing selected device even for the same size
					comparison_logic="-le"
					;;
				*)
					# In case of unrecognized/unsupported indication use smallest as default choice
					# If we want the first of the smallests then change the selected device only if the size is strictly smaller
					comparison_logic="-lt"
					;;
			esac
			nodeosdisk_device_name=""
			for current_device in ${available_st_devices}; do
				current_size=$(blockdev --getsize64 "/dev/${current_device}")
				if [ -z "${nodeosdisk_device_name}" ]; then
					nodeosdisk_device_name="${current_device}"
					nodeosdisk_device_size="${current_size}"
				else
					if [ ${current_size} ${comparison_logic} ${nodeosdisk_device_size} ]; then
						nodeosdisk_device_name="${current_device}"
						nodeosdisk_device_size="${current_size}"
					fi
				fi
			done
			;;
	esac
fi
echo "Assigned OS disk ${nodeosdisk_device_name}" 1>&2
# Remove the OS disk from the available devices
available_st_devices="$(echo "${available_st_devices}" | sed -e "/^${nodeosdisk_device_name}\$/d")"

# Assign extra disks for use as node-local and/or replicated storage (based on distinct LVM volume groups)
# TODO: allow use of multiple disks for each of the volume groups

# Detect desired extra-disk setup for node-local storage
# Determine node-local extra-disk choice
given_extradisk_localst=$(sed -n -e 's/^.*hvp_localstdisk=\(\S*\).*$/\1/p' /proc/cmdline)
# No indication on node-local extra-disk choice: use default choice
if [ -z "${given_extradisk_localst}" ]; then
	given_extradisk_localst="${default_extradisk_localst}"
fi
if [ -b "/dev/${given_extradisk_localst}" ]; then
	# If the given string is a device name then use that
	extradisk_localst_device_name="${given_extradisk_localst}"
	extradisk_localst_device_size=$(blockdev --getsize64 "/dev/${extradisk_localst_device_name}")
else
	# If the given string is a generic indication then find the proper device
	case "${given_extradisk_localst}" in
		skip)
			formerly_available_st_devices="${available_st_devices}"
			available_st_devices=""
			;;
		smallest)
			# Note: Strict comparison means that we will choose the first of the smallests
			comparison_logic="-lt"
			;;
		*)
			# In case of unrecognized/unsupported indication use largest as default choice
			# Note: Strict comparison means that we will choose the first of the largests
			comparison_logic="-gt"
			;;
	esac
	extradisk_localst_device_name=""
	for current_device in ${available_st_devices}; do
		current_size=$(blockdev --getsize64 /dev/${current_device})
		if [ -z "${extradisk_localst_device_name}" ]; then
			extradisk_localst_device_name="${current_device}"
			extradisk_localst_device_size="${current_size}"
		else
			if [ ${current_size} ${comparison_logic} ${extradisk_localst_device_size} ]; then
				extradisk_localst_device_name="${current_device}"
				extradisk_localst_device_size="${current_size}"
			fi
		fi
	done
fi
# Remove the node-local extra-disk from the available devices
available_st_devices="$(echo "${available_st_devices}" | sed -e "/^${extradisk_localst_device_name}\$/d")"
if [ "${given_extradisk_localst}" = "skip" ]; then
	available_st_devices="${formerly_available_st_devices}"
else
	if [ -n "${extradisk_localst_device_name}" ]; then
		echo "Assigned node-local extra disk ${extradisk_localst_device_name}" 1>&2
	else
		echo "No node-local extra disk assigned" 1>&2
	fi
fi

# Detect desired extra-disk setup for replicated storage
# Determine replicated extra-disk choice
given_extradisk_replicatedst=$(sed -n -e 's/^.*hvp_replicatedstdisk=\(\S*\).*$/\1/p' /proc/cmdline)
# No indication on replicated extra-disk choice: use default choice
if [ -z "${given_extradisk_replicatedst}" ]; then
	given_extradisk_replicatedst="${default_extradisk_replicatedst}"
fi
if [ -b "/dev/${given_extradisk_replicatedst}" ]; then
	# If the given string is a device name then use that
	extradisk_replicatedst_device_name="${given_extradisk_replicatedst}"
	extradisk_replicatedst_device_size=$(blockdev --getsize64 "/dev/${extradisk_replicatedst_device_name}")
else
	# If the given string is a generic indication then find the proper device
	case "${given_extradisk_replicatedst}" in
		skip)
			formerly_available_st_devices="${available_st_devices}"
			available_st_devices=""
			;;
		largest)
			# Note: Strict comparison means that we will choose the first of the largests
			comparison_logic="-gt"
			;;
		*)
			# In case of unrecognized/unsupported indication use smallest as default choice
			# Note: Strict comparison means that we will choose the first of the smallests
			comparison_logic="-lt"
			;;
	esac
	extradisk_replicatedst_device_name=""
	for current_device in ${available_st_devices}; do
		current_size=$(blockdev --getsize64 /dev/${current_device})
		if [ -z "${extradisk_replicatedst_device_name}" ]; then
			extradisk_replicatedst_device_name="${current_device}"
			extradisk_replicatedst_device_size="${current_size}"
		else
			if [ ${current_size} ${comparison_logic} ${extradisk_replicatedst_device_size} ]; then
				extradisk_replicatedst_device_name="${current_device}"
				extradisk_replicatedst_device_size="${current_size}"
			fi
		fi
	done
fi
# Remove the replicated extra-disk from the available devices
available_st_devices="$(echo "${available_st_devices}" | sed -e "/^${extradisk_replicatedst_device_name}\$/d")"
if [ "${given_extradisk_localst}" = "skip" ]; then
	available_st_devices="${formerly_available_st_devices}"
else
	if [ -n "${extradisk_replicatedst_device_name}" ]; then
		echo "Assigned replicated extra disk ${extradisk_replicatedst_device_name}" 1>&2
	else
		echo "No replicated extra disk assigned" 1>&2
	fi
fi

# Clean up disks from any (RAID, LVM etc.) previous setup
# Note: resetting disk devices may be needed since leftover configurations may interfer with installation and/or setup later on
# Determine disk wiping choice
given_disk_wiping=$(sed -n -e 's/^.*hvp_diskwiping=\(\S*\).*$/\1/p' /proc/cmdline)
# No indication on disk wiping choice: use default choice
if [ -z "${given_disk_wiping}" ]; then
	given_disk_wiping="${default_disk_wiping}"
fi
devices_to_wipe=""
case "${given_disk_wiping}" in
	none)
		devices_to_wipe=""
		;;
	all)
		devices_to_wipe="${all_st_devices}"
		;;
	os)
		devices_to_wipe="${nodeosdisk_device_name}"
		;;
	extra)
		devices_to_wipe="${extradisk_localst_device_name} ${extradisk_replicatedst_device_name}"
		;;
	*)
		# In case of unrecognized/unsupported indication use only the allocated disks as default choice
		devices_to_wipe="${nodeosdisk_device_name} ${extradisk_localst_device_name} ${extradisk_replicatedst_device_name}"
		;;
esac
# Clean up disks from any previous LVM setup
# Note: it seems that simply wiping below is not enough
# Note: LVM is not natively supported in Ignition
# Note: default lvm.conf excludes all devices on Fedora CoreOS Live - overriding here
# TODO: switch to devices file use and add all to-be-configured disks with lvmdevices
sed -i -e '/^\s*filter\s*=\s*/s/r|/a|/' /etc/lvm/lvm.conf
pvscan --cache -aay
vgscan -v
for disk_name in ${devices_to_wipe}; do
	for vg_name in $(vgs --noheadings -o pv_name,vg_name | awk "{if (\$1 ~ /^\/dev\/${disk_name}/) {print \$2}}" | sort -u); do
		echo "Removing VG ${vg_name}" 1>&2
		vgremove -v -y "${vg_name}"
		udevadm settle --timeout=5
	done
	for pv_name in $(pvs --noheadings -o pv_name | awk "{if (\$1 ~ /^\/dev\/${disk_name}/) {print \$1}}" | sort -u); do
		echo "Removing PV ${pv_name}" 1>&2
		pvremove -v -ff -y "${pv_name}"
		udevadm settle --timeout=5
	done
done
# Wipe disks
for current_device in ${devices_to_wipe}; do
	echo "Wiping device ${current_device}" 1>&2
	wipefs --all --force "/dev/${current_device}"
	# Note: wipefs seems not to be enough - adding zero-dd of the beginning and end of the disk
	dd if=/dev/zero of=/dev/${current_device} bs=1M count=10
	dd if=/dev/zero of=/dev/${current_device} bs=1M count=10 seek=$(($(blockdev --getsize64 /dev/${current_device}) / (1024 * 1024) - 10))
	kpartx -dvs "/dev/${current_device}"
	udevadm settle --timeout=5
done

# Configure extra disks

# Create expected LVM layout and related filesystems if the expected PV is not already used
localst_actual_vg_name=""
if [ -b "/dev/${extradisk_localst_device_name}" ]; then
	if ! pvs -q --noheadings -o pv_name | grep -qw "${extradisk_localst_device_name}" ; then
		vgcreate -qq -s 32m local "/dev/${extradisk_localst_device_name}"
		localst_actual_vg_name="local"
	else
		echo "Extra disk for node-local storage already in use as PV - skipping VG creation (/dev/${extradisk_localst_device_name})" 1>&2
	fi
fi
replicatedst_actual_vg_name=""
if [ -b "/dev/${extradisk_replicatedst_device_name}" ]; then
	if ! pvs -q --noheadings -o pv_name | grep -qw "${extradisk_replicatedst_device_name}" ; then
		vgcreate -qq -s 32m replicated "/dev/${extradisk_replicatedst_device_name}"
		replicatedst_actual_vg_name="replicated"
	else
		echo "Extra disk for replicated storage already in use as PV - skipping VG creation (/dev/${extradisk_replicatedst_device_name})" 1>&2
	fi
fi

echo "pre-hook script version ${pre_version} exiting"
