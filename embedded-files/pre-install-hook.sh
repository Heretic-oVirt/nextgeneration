# Script sourced immediately before the embedded Fedora CoreOS installer invocation is initiated
# Note: to influence disk wiping logic add hvp_diskwiping=XXX where XXX is one of none, all, os, extra, used*
# Note: to influence selection of the target disk for node OS installation add hvp_nodeosdisk=AAA where AAA is either the device name (sda, sdb ecc) or one of first, last, smallest*, last-smallest
# Note: to influence selection of the target disk for node-local storage add hvp_localstdisk=BBB where BBB is either the device name (sda, sdb ecc) or one of skip, largest*, smallest, fastest, slowest
# Note: to influence selection of the target disk for replicated storage add hvp_replicatedstdisk=CCC where CCC is either the device name (sda, sdb ecc) or one of skip*, largest, smallest, fastest, slowest
# Note: to set node type add hvp_nodetype=UU where UU is a custom qualifier (values depend on installation type and are managed by the provided post_install_hook_custom_actions function)
# Note: to set timezone add hvp_timezone=XXX where XXX is one of the timezones available in /usr/share/zoneinfo/
# Note: to set keyboard layout add hvp_kblayout=TT where TT is one of the keyboard maps available in /usr/lib/kbd/keymaps/xkb/ 
# Note: to influence hostname assignment logic add hvp_hostname_assignment=YYY where YYY is one of fixed*, automated
# Note: to influence hostname add hvp_hostname=ZZZ where ZZZ becomes either the full hostname or the prefix, depending on the assignment logic selected (use "" or '' to explicitly force it to the empty string, obtaining either the builtin CoreOS default or a non-prefixed automated hostname)
# Note: to influence domain name add hvp_domainname=WWW where WWW becomes the DNS domain name and gets appended to the hostname default being "lan.private" except when the hostname has been set to "localhost" which imposes "localdomain" as DNS domain name)
# Note: to force network configuration persistence add hvp_persistnmconf=XXX where XX is one of true*, false
# Note: to force network configuration immediate enacting add hvp_enactnmconf=XXX where XX is one of true, false*
# Note: to set custom addressing on autodetected NICs add hvp_ipaddr=x.x.x.x/yy where x.x.x.x is the machine IP and yy is the prefix on the network (all NICs with carrier detected get bonded together and configured with the given IP)
# Note: to set custom gateway IP on autodetected NICs add hvp_gateway=n.n.n.n/yy where n.n.n.n is the gateway IP and yy is the prefix on the network (default being the first or last address on the given network)
# Note: to influence custom search start for IP address on autodetected NICs add hvp_startipaddr=x.x.x.x/yy where x.x.x.x is the search start IP address for autoassignment and yy is the prefix on the network (search going up by default to the last available address on the specified network)
# Note: to influence custom search range for IP address on autodetected NICs add hvp_rangeipaddr=NN where NN is the range of IP addresses to be searched for autoassignment
# Note: to set custom bonding mode for autodetected NICs add hvp_bondmode=vvvv where vvvv is the bonding mode, either none, activepassive*, roundrobin or lacp (none means that only the first NIC correctly autoconfigured will be used)
# Note: to set custom bonding options for autodetected NICs add hvp_bondopts=aaa=bbb;ccc=ddd where aaa=bbb and ccc=ddd are the bonding options for the specific bonding mode selected (the default depending on the selected bonding mode)
# Note: to set custom nameserver IPs add hvp_nameservers=w.w.w.w,z.z.z.z,y.y.y.y where w.w.w.w z.z.z.z y.y.y.y etc. are up to 3 comma-separated nameserver IPs with the default being 1.1.1.1 alone
# Note: to set custom NTP server names/IPs add hvp_ntpservers=ntp0,ntp1,ntp2,ntp3 where ntpN are the comma-separated NTP servers' fully qualified domain names or IPs
# Note: to set custom admin username add hvp_adminname=myadmin where myadmin is the admin username (default being hvpadmin)
# Note: to set custom admin password add hvp_adminpwd=myothersecret where myothersecret is the SHA512 hash of the admin user password (default being the SHA512 hash of hvpdemo)
# Note: to set custom admin SSH public key add hvp_adminsshpubkey=mysshpubkey where mysshpubkey is the SSH public key which will allow SSH login as the admin user (default being a custom development SSH public key)
# Note: to influence embedded package removal logic add hvp_removepkgs=XXX where XXX is a comma-separated list of package names present by default and to be removed (use "" or '' to explicitly set it to the empty list)
# Note: to influence embedded package replacement logic add hvp_replacepkgs=XXX where XXX is a comma-separated list of package names present by default and to be replaced (use "" or '' to explicitly set it to the empty list)
# Note: to influence package addition logic add hvp_addpkgs=XXX where XXX is a comma-separated list of package names to be installed (use "" or '' to explicitly set it to the empty list)
# Note: to influence embedded kernel argument removal logic add hvp_removekargs=XXX where XXX is a comma-separated list of kernel arguments present by default and to be removed (use "" or '' to explicitly set it to the empty list)
# Note: to influence embedded kernel argument replacement logic add hvp_replacekargs=XXX where XXX is a comma-separated list of kernel arguments present by default and to be replaced (use "" or '' to explicitly set it to the empty list)
# Note: to influence kernel argument addition logic add hvp_addkargs=XXX where XXX is a comma-separated list of kernel arguments to be installed (use "" or '' to explicitly set it to the empty list)
# Note: to influence service masking logic add hvp_masksvcs=XXX where XXX is a comma-separated list of unit names to be masked (use "" or '' to explicitly set it to the empty list)
# Note: to influence service disabling logic add hvp_disablesvcs=XXX where XXX is a comma-separated list of unit names to be disabled (use "" or '' to explicitly set it to the empty list)
# Note: to influence service enabling logic add hvp_enablesvcs=XXX where XXX is a comma-separated list of unit names to be enabled (use "" or '' to explicitly set it to the empty list)

# TODO: add support for setting nonstandard MTU (practically usable only when supporting multiple VLANs or segregating clients on a different L2 network)

pre_version="2025030201"

echo "pre-hook script version ${pre_version} starting"

# Note: Customizable baseline defaults are kept inside /etc/sysconfig/custom-install and propagated as environment variables through systemd
# Note: Hardcoded fallback defaults are written inline inside the scripts themselves
# Note: User-modifiable defaults can be put inside the external configuration fragments

# A simplistic regex matching IP addresses
# TODO: add support for IPv6
# TODO: use a complete/correct regex (verifying that it works with the grep version in use)
IPregex='[0-9]*[.][0-9]*[.][0-9]*[.][0-9]*'

# A general IP add/subtract function to allow classless subnets +/- offsets
# Note: derived from https://stackoverflow.com/questions/33056385/increment-ip-address-in-a-shell-script
# TODO: add support for IPv6
ipmat() {
	local given_ip=$1
	local given_diff=$2
	local given_op=$3
	# TODO: perform better checking on parameters
	if [ -z "${given_ip}" -o -z "${given_diff}" -o -z "${given_op}" ]; then
		echo ""
		return 255
	fi
	local given_ip_hex=$(printf '%.2X%.2X%.2X%.2X' $(echo "${given_ip}" | sed -e 's/\./ /g'))
	local given_diff_hex=$(printf '%.8X' "${given_diff}")
	local result_ip_hex=$(printf '%.8X' $(echo $(( 0x${given_ip_hex} ${given_op} 0x${given_diff_hex} ))))
	local result_ip=$(printf '%d.%d.%d.%d' $(echo "${result_ip_hex}" | sed -r 's/(..)/0x\1 /g'))
	echo "${result_ip}"
	return 0
}

# A general IP distance function to derive offsets from classless IP addresses
# Note: derived from https://stackoverflow.com/questions/33056385/increment-ip-address-in-a-shell-script
# TODO: add support for IPv6
ipdiff() {
        local given_ip1=$1
        local given_ip2=$2
        # TODO: perform better checking on parameters
        if [ -z "${given_ip1}" -o -z "${given_ip2}" ]; then
                echo ""
                return 255
        fi
        local given_ip1_hex=$(printf '%.2X%.2X%.2X%.2X' $(echo "${given_ip1}" | sed -e 's/\./ /g'))
        local given_ip2_hex=$(printf '%.2X%.2X%.2X%.2X' $(echo "${given_ip2}" | sed -e 's/\./ /g'))
        local result=$(echo $(( 0x${given_ip1_hex} - 0x${given_ip2_hex} )) | sed -e 's/^-//')
        echo "${result}"
        return 0
}

# Detect any configuration fragments and load them into the installation environment together with the Ignition file
# Note: only embedded/HTTP/HTTPS/TFTP methods are supported
# TODO: support also S3, ABFS and GS
local_igncfg_cache="/tmp/igncfg-pre"
mkdir -p ${local_igncfg_cache}
given_ign_source="$(cat /proc/cmdline | sed -n -e 's/^.*\s*coreos\.inst\.ignition_url=\(\S*\)\s*.*$/\1/p')"
if [ -z "${given_ign_source}" ]; then
	# Note: if we are here and no Ignition URL has been explicitly specified, then it must have been embedded into the ISO
	if [ -n "${default_ign_source}" ]; then
		given_ign_source="${default_ign_source}"
	fi
fi
if [ -n "${given_ign_source}" ]; then
	ign_dev=""
	if echo "${given_ign_source}" | grep -q "^/run/media/iso" ; then
		# Note: blindly assuming an embedded subfolder on a custom ISO image
		ign_host="localhost"
		ign_dev="$(dirname ${given_ign_source})"
		ign_fstype="filesystem"
	elif echo "${given_ign_source}" | grep -Eq '^(http|https|tftp):' ; then
		# Note: blindly extracting URL from kernel commandline
		ign_host="$(echo ${given_ign_source} | sed -e 's%^.*//%%' -e 's%/.*$%%')"
		ign_dev="$(echo ${given_ign_source} | sed -e 's%/[^/]*$%%')"
		ign_fstype="url"
	else
		echo "Unsupported Ignition source detected" 1>&2
	fi
	if [ -z "${ign_dev}" ]; then
		echo "Unable to extract Ignition source - skipping configuration fragments retrieval" 1>&2
	else
		# Note: for network-based Ignition file retrieval methods we extract the relevant NIC MAC address to get the machine-specific fragment
		pushd ${local_igncfg_cache}
		if [ -n "${default_ign_custom_frags}" ]; then
			ign_custom_frags="${default_ign_custom_frags}"
		else
			ign_custom_frags=""
		fi
		if [ "${ign_fstype}" = "url" ]; then
			# Note: we detect the NIC device name as the one detaining the route towards the host holding the Ignition file
			# Note: regarding the Ignition file host: we assume that if it has not directly been given as an IP address then it is a DNS FQDN
			if ! ipcalc -s -c  "${ign_host}" ; then
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
			# Retrieve the Ignition file
			# Note: any error in retrieving a remote custom Ignition file will be fatal
			echo "Attempting network retrieval of Ignition file ${given_ign_source}" 1>&2
			curl -O -C - "${given_ign_source}"
		else
			# Note: filesystem-based Ignition file retrieval autodetected
			for custom_frag in ${ign_custom_frags} ; do
				echo "Attempting filesystem retrieval of configuration fragment ${custom_frag}" 1>&2
				if [ -f "${ign_dev}/${custom_frag}" ]; then
					cp "${ign_dev}/${custom_frag}" .
				fi
			done
			# Retrieve the Ignition file
			# Note: any error in retrieving a local custom Ignition file will be fatal
			echo "Attempting filesystem retrieval of Ignition file ${given_ign_source}" 1>&2
			cp "${given_ign_source}" .
		fi
		popd
	fi
fi
# Load any configuration fragment found, in the proper order
# Note: configuration-fragment defaults will override hardcoded defaults
# Note: commandline parameters will override configuration-fragment and hardcoded defaults
# Note: configuration fragments get executed with full privileges and no further controls beside a bare syntax check: obvious security implications must be taken care of (e.g.: use HTTPS on a private network for network-retrieved Ignition file and fragments)
pushd ${local_igncfg_cache}
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
# Note: the pre_install_hook_custom_actions function is invoked here after dynamic configuration has been retrieved and loaded but before any dynamic detection has been performed
# Note: it is assumed that the pre-install hook script will make available to the pre_install_hook_custom_actions function only the following variables:
# inst_version
# pre_version
# given_ign_source
# ign_fstype
# ign_dev
pre_install_hook_custom_actions || true

# Find the storage devices
# Note: we want the device list alphabetically ordered anyway
all_st_devices="$(lsblk -d -r -n -o NAME | grep -Ev '^(loop|fd|sr)[[:digit:]]*[[:space:]]*' | awk '{print $1}' | sort)"
# Note: we assume that all suitable devices are available for use
available_st_devices="${all_st_devices}"

# Find the NVMe devices for speed-based comparisons
all_nvme_devices="$(nvme list -o json | jq -r '.Devices[].DevicePath' | sed -e 's>^/dev/>>g' | sort)"
# Note: we assume that all NVMe devices are available for use
available_nvme_devices="${all_nvme_devices}"

# Find all rotational and non-rotational devices for speed-based comparisons
all_rotational_devices=""
all_nonrotational_devices=""
for current_device in ${all_st_devices}; do
	current_rotational=$(cat /sys/block/${current_device}/queue/rotational)
	if [ "${current_rotational}" = "0" ]; then
		all_nonrotational_devices="${all_nonrotational_devices} ${current_device}"
	else
		all_rotational_devices="${all_rotational_devices} ${current_device}"
	fi
done
# Note: we assume that all NVMe devices are available for use
available_rotational_devices="${all_rotational_devices}"
available_nonrotational_devices="${all_nonrotational_devices}"

# Determine node OS disk choice
given_nodeosdisk=$(sed -n -e 's/^.*hvp_nodeosdisk=\(\S*\).*$/\1/p' /proc/cmdline)
# No indication on node OS disk choice: use default choice
if [ -z "${given_nodeosdisk}" ]; then
	if [ -n "${default_nodeosdisk}" ]; then
		given_nodeosdisk="${default_nodeosdisk}"
	else
		given_nodeosdisk="smallest"
	fi
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
available_nvme_devices="$(echo "${available_nvme_devices}" | sed -e "/^${nodeosdisk_device_name}\$/d")"
available_rotational_devices="$(echo "${available_rotational_devices}" | sed -e "/^${nodeosdisk_device_name}\$/d")"
available_nonrotational_devices="$(echo "${available_nonrotational_devices}" | sed -e "/^${nodeosdisk_device_name}\$/d")"

# Assign extra disks for use as node-local and/or replicated storage (based on distinct LVM volume groups)
# TODO: allow configuration of multiple disks (DM RAID 0/1/5/6 underneath) for each of storage types
# TODO: support configuration of VDO via LVM

# Detect desired extra-disk setup for node-local storage
# Determine node-local extra-disk choice
given_extradisk_localst=$(sed -n -e 's/^.*hvp_localstdisk=\(\S*\).*$/\1/p' /proc/cmdline)
# No indication on node-local extra-disk choice: use default choice
if [ -z "${given_extradisk_localst}" ]; then
	if [ -n "${default_extradisk_localst}" ]; then
		given_extradisk_localst="${default_extradisk_localst}"
	else
		given_extradisk_localst="largest"
	fi
fi
if [ -b "/dev/${given_extradisk_localst}" ]; then
	# If the given string is a device name then use it
	extradisk_localst_device_name="${given_extradisk_localst}"
	extradisk_localst_device_size=$(blockdev --getsize64 "/dev/${extradisk_localst_device_name}")
else
	# If the given string is a generic indication then find the proper device
	case "${given_extradisk_localst}" in
		skip)
			comparison_type="none"
			formerly_available_st_devices="${available_st_devices}"
			available_st_devices=""
			;;
		fastest)
			# Note: Strict comparison means that we will choose the first of the NVMe/SSD/rotational
			comparison_type="speed"
			;;
		slowest)
			# Note: Strict comparison means that we will choose the first of the rotational/SSD/NVMe
			comparison_type="speed"
			;;
		smallest)
			# Note: Strict comparison means that we will choose the first of the smallests
			comparison_type="size"
			comparison_logic="-lt"
			;;
		largest|*)
			# In case of unrecognized/unsupported indication use largest as default choice
			# Note: Strict comparison means that we will choose the first of the largests
			comparison_type="size"
			comparison_logic="-gt"
			;;
	esac
	extradisk_localst_device_name=""
	if [ "${comparison_type}" = "size" ]; then
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
	elif [ "${comparison_type}" = "speed" ]; then
		case "${given_extradisk_localst}" in
			fastest)
				for current_device in ${available_nvme_devices}; do
					current_size=$(blockdev --getsize64 /dev/${current_device})
					extradisk_localst_device_name="${current_device}"
					extradisk_localst_device_size="${current_size}"
					break
				done
				if [ -z "${extradisk_localst_device_name}" ]; then
					for current_device in ${available_nonrotational_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_localst_device_name="${current_device}"
						extradisk_localst_device_size="${current_size}"
						break
					done
				fi
				if [ -z "${extradisk_localst_device_name}" ]; then
					for current_device in ${available_rotational_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_localst_device_name="${current_device}"
						extradisk_localst_device_size="${current_size}"
						break
					done
				fi
				;;
			slowest)
				for current_device in ${available_rotational_devices}; do
					current_size=$(blockdev --getsize64 /dev/${current_device})
					extradisk_localst_device_name="${current_device}"
					extradisk_localst_device_size="${current_size}"
					break
				done
				if [ -z "${extradisk_localst_device_name}" ]; then
					for current_device in ${available_nonrotational_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_localst_device_name="${current_device}"
						extradisk_localst_device_size="${current_size}"
						break
					done
				fi
				if [ -z "${extradisk_localst_device_name}" ]; then
					for current_device in ${available_nvme_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_localst_device_name="${current_device}"
						extradisk_localst_device_size="${current_size}"
						break
					done
				fi
				;;
		esac
	fi
fi
# Remove the node-local extra-disk from the available devices
if [ "${given_extradisk_localst}" = "skip" ]; then
	available_st_devices="${formerly_available_st_devices}"
	echo "Skipping node-local extra disk assignment" 1>&2
else
	available_st_devices="$(echo "${available_st_devices}" | sed -e "/^${extradisk_localst_device_name}\$/d")"
	available_nvme_devices="$(echo "${available_nvme_devices}" | sed -e "/^${extradisk_localst_device_name}\$/d")"
	available_rotational_devices="$(echo "${available_rotational_devices}" | sed -e "/^${extradisk_localst_device_name}\$/d")"
	available_nonrotational_devices="$(echo "${available_nonrotational_devices}" | sed -e "/^${extradisk_localst_device_name}\$/d")"
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
	if [ -n "${default_extradisk_replicatedst}" ]; then
		given_extradisk_replicatedst="${default_extradisk_replicatedst}"
	else
		given_extradisk_replicatedst="skip"
	fi
fi
if [ -b "/dev/${given_extradisk_replicatedst}" ]; then
	# If the given string is a device name then use that
	extradisk_replicatedst_device_name="${given_extradisk_replicatedst}"
	extradisk_replicatedst_device_size=$(blockdev --getsize64 "/dev/${extradisk_replicatedst_device_name}")
else
	# If the given string is a generic indication then find the proper device
	case "${given_extradisk_replicatedst}" in
		skip)
			comparison_type="none"
			formerly_available_st_devices="${available_st_devices}"
			available_st_devices=""
			;;
		fastest)
			# Note: Strict comparison means that we will choose the first of the NVMe/SSD/rotational
			comparison_type="speed"
			;;
		slowest)
			# Note: Strict comparison means that we will choose the first of the rotational/SSD/NVMe
			comparison_type="speed"
			;;
		largest)
			# Note: Strict comparison means that we will choose the first of the largests
			comparison_type="size"
			comparison_logic="-gt"
			;;
		smallest|*)
			# In case of unrecognized/unsupported indication use smallest as default choice
			# Note: Strict comparison means that we will choose the first of the smallests
			comparison_type="size"
			comparison_logic="-lt"
			;;
	esac
	extradisk_replicatedst_device_name=""
	if [ "${comparison_type}" = "size" ]; then
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
	elif [ "${comparison_type}" = "speed" ]; then
		case "${given_extradisk_replicatedst}" in
			fastest)
				for current_device in ${available_nvme_devices}; do
					current_size=$(blockdev --getsize64 /dev/${current_device})
					extradisk_replicatedst_device_name="${current_device}"
					extradisk_replicatedst_device_size="${current_size}"
					break
				done
				if [ -z "${extradisk_replicatedst_device_name}" ]; then
					for current_device in ${available_nonrotational_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_replicatedst_device_name="${current_device}"
						extradisk_replicatedst_device_size="${current_size}"
						break
					done
				fi
				if [ -z "${extradisk_replicatedst_device_name}" ]; then
					for current_device in ${available_rotational_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_replicatedst_device_name="${current_device}"
						extradisk_replicatedst_device_size="${current_size}"
						break
					done
				fi
				;;
			slowest)
				for current_device in ${available_rotational_devices}; do
					current_size=$(blockdev --getsize64 /dev/${current_device})
					extradisk_replicatedst_device_name="${current_device}"
					extradisk_replicatedst_device_size="${current_size}"
					break
				done
				if [ -z "${extradisk_replicatedst_device_name}" ]; then
					for current_device in ${available_nonrotational_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_replicatedst_device_name="${current_device}"
						extradisk_replicatedst_device_size="${current_size}"
						break
					done
				fi
				if [ -z "${extradisk_replicatedst_device_name}" ]; then
					for current_device in ${available_nvme_devices}; do
						current_size=$(blockdev --getsize64 /dev/${current_device})
						extradisk_replicatedst_device_name="${current_device}"
						extradisk_replicatedst_device_size="${current_size}"
						break
					done
				fi
				;;
		esac
	fi
fi
# Remove the replicated extra-disk from the available devices
if [ "${given_extradisk_localst}" = "skip" ]; then
	available_st_devices="${formerly_available_st_devices}"
	echo "Skipping replicated extra disk assignment" 1>&2
else
	available_st_devices="$(echo "${available_st_devices}" | sed -e "/^${extradisk_replicatedst_device_name}\$/d")"
	available_nvme_devices="$(echo "${available_nvme_devices}" | sed -e "/^${extradisk_replicatedst_device_name}\$/d")"
	available_rotational_devices="$(echo "${available_rotational_devices}" | sed -e "/^${extradisk_replicatedst_device_name}\$/d")"
	available_nonrotational_devices="$(echo "${available_nonrotational_devices}" | sed -e "/^${extradisk_replicatedst_device_name}\$/d")"
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
	if [ -n "${default_disk_wiping}" ]; then
		given_disk_wiping="${default_disk_wiping}"
	else
		given_disk_wiping="used"
	fi
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
	used|*)
		# In case of unrecognized/unsupported indication use only the allocated disks as default choice
		devices_to_wipe="${nodeosdisk_device_name} ${extradisk_localst_device_name} ${extradisk_replicatedst_device_name}"
		;;
esac
# Clean up disks from any previous LVM setup
# Note: it seems that simply wiping below is not enough
# Note: LVM is not natively supported in Ignition
# Note: automatically detecting whether to use LVM filter or the newer lvmdevices feature
use_lvm_filter="false"
if grep -q '^[[:space:]]*use_devicesfile[[:space:]]*=[[:space:]]*0' /etc/lvm/lvm.conf ; then
	use_lvm_filter="true"
elif grep -q '^[[:space:]]*use_devicesfile[[:space:]]*=[[:space:]]*1' /etc/lvm/lvm.conf ; then
	use_lvm_filter="false"
fi
if [ ! -f /etc/lvm/devices/system.devices -o "${use_lvm_filter}" = "true" ]; then
	# Note: default lvm.conf excludes all devices on Fedora CoreOS Live - overriding here
	sed -i -e '/^\s*filter\s*=\s*/s/r|/a|/' /etc/lvm/lvm.conf
else
	lvmdevices --update
fi
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
	if ! pvs -q --noheadings -o pv_name | grep -wq "${extradisk_localst_device_name}" ; then
		localst_actual_vg_name="local"
		# Note: since we are using LVM, there is no need to use a persistent name for the disk
		vgcreate -qq -s 32m "${localst_actual_vg_name}" "/dev/${extradisk_localst_device_name}"
	else
		echo "Extra disk for node-local storage already in use as PV - skipping VG creation (/dev/${extradisk_localst_device_name})" 1>&2
	fi
fi
replicatedst_actual_disk_name=""
if [ -b "/dev/${extradisk_replicatedst_device_name}" ]; then
	if ! pvs -q --noheadings -o pv_name | grep -wq "${extradisk_replicatedst_device_name}" ; then
		# TODO: find a persistent name for the disk
		replicatedst_actual_disk_name="/dev/${extradisk_replicatedst_device_name}"
		# Note: we do not create any VG since depending on the replicated storage type it will be done differently
	else
		echo "Extra disk for replicated storage already in use as PV - skipping VG creation (/dev/${extradisk_replicatedst_device_name})" 1>&2
	fi
fi

# Determine system timezone
# Note: Validity checking is performed at configuration time in post-install hook and if invalid the built-in default is left untouched
given_timezone="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_timezone=\(\S*\).*$/\1/p')"
if [ -z "${given_timezone}" ]; then
	if [ -n "${default_timezone}" ]; then
		given_timezone="${default_timezone}"
	else
		given_timezone="UTC"
	fi
elif [ "${given_timezone}" = '""' -o "${given_timezone}" = "''" ]; then
	given_timezone=""
fi

# Determine system keyboard layout
# Note: Validity checking is performed at configuration time in post-install hook and if invalid the built-in default is left untouched
given_kblayout="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_kblayout=\(\S*\).*$/\1/p')"
if [ -z "${given_kblayout}" ]; then
	if [ -n "${default_kblayout}" ]; then
		given_kblayout="${default_kblayout}"
	else
		given_kblayout="us"
	fi
elif [ "${given_kblayout}" = '""' -o "${given_kblayout}" = "''" ]; then
	given_kblayout=""
fi

# Determine system hostname
# TODO: perform syntax/validity check
given_hostname_assignment="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_hostname_assignment=\(\S*\).*$/\1/p')"
if [ -z "${given_hostname_assignment}" ]; then
	if [ -n "${default_hostname_assignment}" ]; then
		given_hostname_assignment="${default_hostname_assignment}"
	else
		given_hostname_assignment="fixed"
	fi
fi
case "${given_hostname_assignment}" in
	fixed)
		;;
	automated)
		;;
	*)
		given_hostname_assignment="fixed"
		;;
esac
given_hostname="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_hostname=\(\S*\).*$/\1/p')"
given_hostname_domain=""
if [ "${given_hostname}" = '""' -o "${given_hostname}" = "''" ]; then
	given_hostname=""
elif [ -z "${given_hostname}" ]; then
	if [ -n "${default_hostname}" ]; then
		given_hostname="${default_hostname}"
	else
		if [ "${given_hostname_assignment}" = "fixed" ]; then
			given_hostname="localhost"
		else
			given_hostname="coreos"
		fi
	fi
else
	# Check whether the given hostname is an FQDN
	if echo "${given_hostname}" | grep -q '[.]' ; then
		# Extract the domain name part from a FQDN hostname
		given_hostname_domain=$(echo "${given_hostname}" | sed -e 's/^[^.]*[.]//')
		# Make sure that the given_hostname variable holds a short name in order to allow appending the domain name below
		given_hostname=$(echo "${given_hostname}" | sed -e 's/^\([^.]*\)[.].*$/\1/')
	fi
fi
# Apply automated hostname logic
if [ "${given_hostname_assignment}" = "automated" ]; then
	if [ -n "${given_hostname}" ]; then
		# Use the given short name as a prefix
		given_hostname="${given_hostname}-"
	fi
	given_hostname="${given_hostname}$(tr -d " .,_:-" < /sys/class/dmi/id/product_serial)"
fi

# Determine DNS domain name
# TODO: perform syntax/validity check
# Note: an explicitly given domain name will override the one specified as part of a FQDN hostname
given_domainname="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_domainname=\(\S*\).*$/\1/p')"
if [ "${given_domainname}" = '""' -o "${given_domainname}" = "''" ]; then
	given_domainname=""
elif [ -z "${given_domainname}" ]; then
	if [ -n "${given_hostname_domain}" ]; then
		given_domainname="${given_hostname_domain}"
	else
		if [ -n "${default_domainname}" ]; then
			given_domainname="${default_domainname}"
		else
			given_domainname="lan.private"
		fi
	fi
fi
if [ "${given_hostname}" = "localhost" ]; then
	given_domainname="localdomain"
fi

# Append DNS domain name to system short hostname
# Note: the system hostname must be a FQDN as per RHEL/Fedora defaults
if [ -n "${given_domainname}" ]; then
	given_hostname="${given_hostname}.${given_domainname}"
fi

# Determine final persisting of NetworkManager configuration
given_persistnmconf="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_persistnmconf=\(\S*\).*$/\1/p')"
if [ "${given_persistnmconf}" = '""' -o "${given_persistnmconf}" = "''" ]; then
	given_persistnmconf=""
elif [ -n "${given_persistnmconf}" ]; then
	# Unconfigure in case of invalid value
	if [ "${given_persistnmconf}" != "true" -a "${given_persistnmconf}" != "false" ]; then
		given_persistnmconf=""
	fi
fi
if [ -z "${given_persistnmconf}" ]; then
	if [ -n "${default_persistnmconf}" ]; then
		given_persistnmconf="${default_persistnmconf}"
	else
		given_persistnmconf="true"
	fi
fi

# Determine immediate enacting of NetworkManager configuration
given_enactnmconf="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_enactnmconf=\(\S*\).*$/\1/p')"
if [ "${given_enactnmconf}" = '""' -o "${given_enactnmconf}" = "''" ]; then
	given_enactnmconf=""
elif [ -n "${given_enactnmconf}" ]; then
	# Unconfigure in case of invalid value
	if [ "${given_enactnmconf}" != "true" -a "${given_enactnmconf}" != "false" ]; then
		given_enactnmconf=""
	fi
fi
if [ -z "${given_enactnmconf}" ]; then
	if [ -n "${default_enactnmconf}" ]; then
		given_enactnmconf="${default_enactnmconf}"
	else
		given_enactnmconf="false"
	fi
fi

# Determine IP address and network configuration
# Note: setting a default_ipaddr is not supported
given_ipaddr=$(sed -n -e "s/^.*hvp_ipaddr=\(\S*\).*$/\1/p" /proc/cmdline)
given_ip=""
if [ -n "${given_ipaddr}" ]; then
	# Check IP validity
	if ! ipcalc -s -c "${given_ipaddr}" ; then
		given_ipaddr=""
	# Check that a proper network prefix was specified otherwise take it later from the gateway IP address
	elif [ "$(ipcalc -s --no-decorate -p "${given_ipaddr}")" = "32" ]; then
		given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
	fi
fi

# Determine search start IP address and network configuration
given_startipaddr=$(sed -n -e "s/^.*hvp_startipaddr=\(\S*\).*$/\1/p" /proc/cmdline)
given_startip=""
if [ -n "${given_ipaddr}" ]; then
	# If a fixed IP address has been explicitly given then forcefully unconfigure the search start IP address
	given_startipaddr=""
elif [ -n "${given_startipaddr}" ]; then
	# Check IP validity
	if ! ipcalc -s -c "${given_startipaddr}" ; then
		given_startipaddr=""
	# Check that a proper network prefix was specified otherwise take it later from the gateway IP address
	elif [ "$(ipcalc -s --no-decorate -p "${given_startipaddr}")" = "32" ]; then
		given_startip=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
	fi
fi
if [ -z "${given_startipaddr}" ]; then
	if [ -n "${default_startipaddr}" ]; then
		# Check IP validity
		if ipcalc -s -c "${default_startipaddr}" ; then
			# Check that a proper network prefix was specified otherwise take it later from the gateway IP address
			if [ "$(ipcalc -s --no-decorate -p "${default_startipaddr}")" = "32" ]; then
				given_startip=$(ipcalc -s --no-decorate -a "${default_startipaddr}")
			else
				given_startipaddr="${default_startipaddr}"
			fi
		fi
	fi
fi

# Determine IP address range
given_rangeipaddr=$(sed -n -e "s/^.*hvp_rangeipaddr=\(\S*\).*$/\1/p" /proc/cmdline)
if [ -n "${given_ipaddr}" ]; then
	# If a fixed IP address has been explicitly given then forcefully unconfigure the search range for IP address
	given_rangeipaddr=""
elif [ -z "${given_rangeipaddr}" ]; then
	# Check whether a default range has been specified, otherwise the search will go up to the last available IP on the network
	if [ -n "${default_rangeipaddr}" ]; then
		# Check that a well formed value has beeen specified
		if echo "${default_rangeipaddr}" | grep -Eq '[[:digit:]]+' ; then
			given_rangeipaddr="${default_rangeipaddr}"
		fi
	fi
elif ! echo "${given_rangeipaddr}" | grep -Eq '[[:digit:]]+' ; then
	# If a malformed value has been specified then forcefully unconfigure the search range for IP address
	given_rangeipaddr=""
fi

# Determine gateway address
# TODO: add meaningful warning messages on stdout/stderr
autoderive_ip="false"
given_gateway=$(sed -n -e "s/^.*hvp_gateway=\(\S*\).*$/\1/p" /proc/cmdline)
if [ -z "${given_gateway}" ]; then
	# No given gateway was specified
	# Differentiate logic depending on whether a given node IP has been explicitly specified or not
	if [ -n "${given_ipaddr}" ]; then
		# Check whether given IP included a valid network prefix or not
		if [-z "${given_ip}" ]; then
			# Check whether a default choice for gateway has been specified
			if [ -n "${default_gateway}" ]; then
				# Check default gateway validity
				if ipcalc -s -c "${default_gateway}" ; then
					# Check whether default gateway included a valid network prefix or not
					if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" = "32" ]; then
						# Since default gateway did not specify a network prefix then adopt the one from given IP address
						default_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					fi
					# Set gateway to default only if it is coherent with given IP address
					if [ "$(ipcalc -s --no-decorate -n "${given_ipaddr}")" = "$(ipcalc -s --no-decorate -n "${default_gateway}")" ]; then
						given_gateway="${default_gateway}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					else
						# Otherwise set it as the first or last address on the given network
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
						given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
						given_prefix=$(ipcalc -s --no-decorate -p "${given_ipaddr}")
						if [ "${given_ip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/${given_prefix}"
						else
							given_gateway="${last_ip}/${given_prefix}"
						fi
					fi
				fi
			else
				# Otherwise set it as the first or last address on the given network
				first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
				last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
				given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
				given_prefix=$(ipcalc -s --no-decorate -p "${given_ipaddr}")
				if [ "${given_ip}" != "${first_ip}" ]; then
					given_gateway="${first_ip}/${given_prefix}"
				else
					given_gateway="${last_ip}/${given_prefix}"
				fi
			fi
		else
			# Given IP address did not specify a network prefix and no explicit gateway was given
			# Check whether a default choice for gateway has been specified
			if [ -n "${default_gateway}" ]; then
				# Check default gateway validity
				if ipcalc -s -c "${default_gateway}" ; then
					# Check whether default gateway included a valid network prefix or not
					if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" = "32" ]; then
						# With no way to deduce a network prefix, assume a class C network and apply it to both gateway and given IP address
						default_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/24"
						given_ipaddr="${given_ip}/24"
					else
						# Apply the prefix deduced from gateway to the given IP address
						given_ipaddr="${given_ip}/$(ipcalc -s --no-decorate -p "${default_gateway}")"
					fi
					# Set gateway to default only if it is coherent with given IP address
					if [ "$(ipcalc -s --no-decorate -n "${given_ipaddr}")" = "$(ipcalc -s --no-decorate -n "${default_gateway}")" ]; then
						given_gateway="${default_gateway}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					else
						# Otherwise set it as the first or last address on the given network
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
						given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
						given_prefix=$(ipcalc -s --no-decorate -p "${given_ipaddr}")
						if [ "${given_ip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/${given_prefix}"
						else
							given_gateway="${last_ip}/${given_prefix}"
						fi
					fi
				else
					# With an invalid default gateway and no network prefix from the given IP address, assume a class C network
					given_ipaddr="${given_ip}/24"
					# Set the gateway to the first or last address on the given network
					first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
					last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
					if [ "${given_ip}" != "${first_ip}" ]; then
						given_gateway="${first_ip}/24"
					else
						given_gateway="${last_ip}/24"
					fi
				fi
			else
				# With no default gateway and no network prefix from the given IP address, assume a class C network
				given_ipaddr="${given_ip}/24"
				# Set the gateway to the first or last address on the given network
				first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
				last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
				if [ "${given_ip}" != "${first_ip}" ]; then
					given_gateway="${first_ip}/24"
				else
					given_gateway="${last_ip}/24"
				fi
			fi
		fi
	else
		# With no given gateway and no given IP address check whether a default gateway has been specified or not
		if [ -n "${default_gateway}" ]; then
			# Check default gateway validity
			if ipcalc -s -c "${default_gateway}" ; then
				# If a valid default gateway was specified then we will deduce everything later from the default gateway IP and prefix
				autoderive_ip="true"
				# No given IP address but the default gateway specifies a proper network
				if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" != "32" ]; then
					given_gateway="${default_gateway}"
					# Make sure that the search start IP address specifies a network prefix
					if [ -n "${given_startip}" ]; then
						# No network prefix was given for the search start IP so apply the prefix from gateway
						given_startipaddr="${given_startip}/$(ipcalc -s --no-decorate -p "${given_gateway}")"
					fi
					# Check search start IP address coherence with gateway and unconfigure it otherwise
					if [ "$(ipcalc -s --no-decorate -n "${given_startipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
						given_startipaddr=""
					fi
				else
					# With no way to deduce a network prefix from the default gateway, check whether search start IP address can provide the missing info
					if [ -z "${given_startip}" ]; then
						if [ -n "${given_startipaddr}" ]; then
							# Applying the network prefix from the search start IP address to the default gateway
							given_gateway="${default_gateway}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
						else
							# With no way to deduce a network prefix from the default gateway and from the search start IP address, assume a class C network and apply it to the default gateway
							given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/24"
						fi
					else
						# With no way to deduce a network prefix from the default gateway and from the search start IP address, assume a class C network and apply it to the default gateway and search start IP address
						given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/24"
						given_startipaddr="${given_startip}/24"
					fi
					# Check search start IP address coherence with gateway and unconfigure it otherwise
					if [ "$(ipcalc -s --no-decorate -n "${given_startipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
						given_startipaddr=""
					fi
				fi
			else
				# With no given gateway, no given IP address and invalid default gateway specified, try to deduce everything from the search start IP address
				if [ -z "${given_startip}" ]; then
					if [ -n "${given_startipaddr}" ]; then
						autoderive_ip="true"
						# Set gateway as the first or last address on the search start IP address network
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
						given_startip=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
						given_prefix=$(ipcalc -s --no-decorate -p "${given_startipaddr}")
						if [ "${given_startip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/${given_prefix}"
						else
							given_gateway="${last_ip}/${given_prefix}"
						fi
					else
						# Nothing can be deduced without a search start IP address at all
						autoderive_ip="false"
					fi
				else
					autoderive_ip="true"
					# Assume class C and apply it to given_startip then set gateway from search start IP address to first or last network IP
					given_startipaddr="${given_startip}/24"
					# Derive everything from the given search start IP address
					first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
					last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
					if [ "${given_startip}" != "${first_ip}" ]; then
						given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
					else
						given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
					fi
				fi
			fi
		else
			# With no given gateway, no given IP address and no default gateway, try to deduce everything from the search start IP address
			if [ -z "${given_startip}" ]; then
				if [ -n "${given_startipaddr}" ]; then
					autoderive_ip="true"
					# Set gateway as the first or last address on the search start IP address network
					first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
					last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
					given_startip=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
					given_prefix=$(ipcalc -s --no-decorate -p "${given_startipaddr}")
					if [ "${given_startip}" != "${first_ip}" ]; then
						given_gateway="${first_ip}/${given_prefix}"
					else
						given_gateway="${last_ip}/${given_prefix}"
					fi
				else
					# Nothing can be deduced without a search start IP address at all
					autoderive_ip="false"
				fi
			else
				autoderive_ip="true"
				# Assume class C and apply it to given_startip then set gateway from search start IP address to first or last network IP
				given_startipaddr="${given_startip}/24"
				# Derive everything from the given search start IP address
				first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
				last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
				if [ "${given_startip}" != "${first_ip}" ]; then
					given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
				else
					given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
				fi
			fi
		fi
	fi
else
	# Check given gateway validity
	if ipcalc -s -c "${given_gateway}" ; then
		# Differentiate logic depending on whether a given IP has been explicitly specified or not
		if [ -n "${given_ipaddr}" ]; then
			# If the given gateway is a pure IP without network prefix then force the prefix from the given IP address
			if [ "$(ipcalc -s --no-decorate -p "${given_gateway}")" = "32" ]; then
				given_gateway="$(ipcalc -s --no-decorate -a "${given_gateway}")/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
			# If the given gateway network does not match the given IP network then the given IP settings take precedence
			elif [ "$(ipcalc -s --no-decorate -n "${given_ipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
				# Set the default gateway as the first or last address on the given network
				first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
				last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
				given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
				if [ "${given_ip}" != "${first_ip}" ]; then
					given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
				else
					given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
				fi
			fi
		else
			# With a valid given gateway, no given IP address and the given gateway specifies a proper network then we will deduce everything later from the given gateway IP and prefix
			if [ "$(ipcalc -s --no-decorate -p "${given_gateway}")" != "32" ]; then
				autoderive_ip="true"
				# Make sure that the search start IP address specifies a network prefix
				if [ -n "${given_startip}" ]; then
					# No network prefix was given for the search start IP so apply the prefix from gateway
					given_startipaddr="${given_startip}/$(ipcalc -s --no-decorate -p "${given_gateway}")"
				fi
				# Check search start IP address coherence with gateway and unconfigure it otherwise
				if [ "$(ipcalc -s --no-decorate -n "${given_startipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
					given_startipaddr=""
				fi
			else
				# If the given gateway is a pure IP address and there was no given IP address then try to derive network parameters from the search start IP address
				if [ -z "${given_startip}" ]; then
					if [ -n "${given_startipaddr}" ]; then
						# Applying the network prefix from the search start IP address to the given gateway
						given_gateway="$(ipcalc -s --no-decorate -a "${given_gateway}")/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
					else
						# With no way to deduce a network prefix from the given gateway and from the search start IP address, assume a class C network and apply it to the given gateway
						given_gateway="$(ipcalc -s --no-decorate -a "${given_gateway}")/24"
					fi
				else
					# With no way to deduce a network prefix from the given gateway and from the search start IP address, assume a class C network and apply it to the given gateway and search start IP address
					given_gateway="$(ipcalc -s --no-decorate -a "${given_gateway}")/24"
					given_startipaddr="${given_startip}/24"
				fi
				# Check search start IP address coherence with gateway and unconfigure it otherwise
				if [ "$(ipcalc -s --no-decorate -n "${given_startipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
					given_startipaddr=""
				fi
			fi
		fi
	else
		# Since given gateway is invalid, try to use the default one
		if [ -n "${default_gateway}" ]; then
			# Check default gateway validity
			if ipcalc -s -c "${default_gateway}" ; then
				# Differentiate logic depending on whether a given IP has been explicitly specified or not
				if [ -n "${given_ipaddr}" ]; then
					# Check whether the given IP specifies a proper network prefix
					if [ -n "${given_ip}" ]; then
						# No network prefix from given IP: check whether the defaut gateway provides it
						if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" != "32" ]; then
							# Apply the prefix from default gateway to given IP
							given_ipaddr="${given_ip}/$(ipcalc -s --no-decorate -p "${default_gateway}")"
							given_gateway="${default_gateway}"
						else
							# No way to derive a network prefix: assume a class C network
							given_ipaddr="${given_ip}/24"
							given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/24"
						fi
					else
						# Check whether the default gateway specifies a network prefix
						if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" = "32" ]; then
							# Apply the network prefix from the given IP
							given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
						else
							given_gateway="${default_gateway}"
						fi
					fi
					# Check network coherence between given IP and gateway, otherwise redefine gateway
					if [ "$(ipcalc -s --no-decorate -n "${given_ipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
						# Set gateway as the first or last address on the given network
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
						given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
						given_prefix=$(ipcalc -s --no-decorate -p "${given_ipaddr}")
						if [ "${given_ip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/${given_prefix}"
						else
							given_gateway="${last_ip}/${given_prefix}"
						fi
					fi
				else
					# No given IP but default gateway is valid (with/without network prefix): autoderive IP later from search start IP address
					autoderive_ip="true"
					# Differentiate logic depending on whether a given search start IP address has been explicitly specified or not
					if [ -n "${given_startipaddr}" ]; then
						# Check whether the given search start IP address specifies a proper network prefix
						if [ -n "${given_startip}" ]; then
							# No network prefix from given search start IP address: check whether the defaut gateway provides it
							if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" != "32" ]; then
								# Apply the prefix from default gateway to given search start IP address
								given_startipaddr="${given_startip}/$(ipcalc -s --no-decorate -p "${default_gateway}")"
								given_gateway="${default_gateway}"
							else
								# No way to derive a network prefix: assume a class C network
								given_startipaddr="${given_startip}/24"
								given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/24"
							fi
						else
							# Check whether the default gateway specifies a network prefix
							if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" = "32" ]; then
								# Apply the network prefix from the given search start IP address
								given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
							else
								given_gateway="${default_gateway}"
							fi
						fi
						# Check network coherence between given search start IP address and gateway, otherwise redefine gateway
						if [ "$(ipcalc -s --no-decorate -n "${given_startipaddr}")" != "$(ipcalc -s --no-decorate -n "${given_gateway}")" ]; then
							# Set gateway as the first or last address on the given network
							first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
							last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
							given_startip=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
							given_prefix=$(ipcalc -s --no-decorate -p "${given_startipaddr}")
							if [ "${given_startip}" != "${first_ip}" ]; then
								given_gateway="${first_ip}/${given_prefix}"
							else
								given_gateway="${last_ip}/${given_prefix}"
							fi
						fi
					else
						# No given search start IP address but default gateway is valid (with/without network prefix): autoderive search start IP address
						# Check whether default gateway provides a proper network prefix
						if [ "$(ipcalc -s --no-decorate -p "${default_gateway}")" != "32" ]; then
							# Set search start IP address as first address on the network identified by the default gateway
							given_startipaddr="$(ipcalc -s --no-decorate --minaddr "${default_gateway}")/$(ipcalc -s --no-decorate -p "${default_gateway}")"
							given_gateway="${default_gateway}"
						else
							# No way to identify network prefix: assume a class C network
							given_gateway="$(ipcalc -s --no-decorate -a "${default_gateway}")/24"
							# Set search start IP address as first address on the network identified by the default gateway
							given_startipaddr="$(ipcalc -s --no-decorate --minaddr "${given_gateway}")/$(ipcalc -s --no-decorate -p "${given_gateway}")"
						fi
					fi
				fi
			else
				# Invalid default gateway and no given gateway
				# Differentiate logic depending on whether a given IP has been explicitly specified or not (copy from below)
				if [ -n "${given_ipaddr}" ]; then
					# Check whether the given IP specifies a proper network prefix
					if [ -n "${given_ip}" ]; then
						# No given/default gateway and the given IP has no network prefix: assume a C class network and set the gateway as the first or last address on the network
						given_ipaddr="${given_ip}/24"
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
						if [ "${given_ip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
						else
							given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
						fi
					else
						# Deduce the network settings from the given IP
						given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
						if [ "${given_ip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
						else
							given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
						fi
					fi
				else
					# With no valid given gateway, no default gateway and no given IP address, try to deduce everything from the search start IP address
					if [ -z "${given_startip}" ]; then
						if [ -n "${given_startipaddr}" ]; then
							autoderive_ip="true"
							# Derive everything from the given search start IP address
							given_startip=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
							first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
							last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
							if [ "${given_startip}" != "${first_ip}" ]; then
								given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
							else
								given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
							fi
						else
							# With no search start IP address there is nothing to deduce - simply restate the fact
							autoderive_ip="false"
						fi
					else
						autoderive_ip="true"
						# With no way to deduce a network prefix from the search start IP address, assume a class C network and apply it to the search start IP address
						given_startipaddr="${given_startip}/24"
						# Derive everything from the given search start IP address
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
						if [ "${given_startip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
						else
							given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
						fi
					fi
				fi
			fi
		else
			# Given gateway is invalid and no default one was provided
			# Differentiate logic depending on whether a given IP has been explicitly specified or not
			if [ -n "${given_ipaddr}" ]; then
				# Check whether the given IP specifies a proper network prefix
				if [ -n "${given_ip}" ]; then
					# No given/default gateway and the given IP has no network prefix: assume a C class network and set the gateway as the first or last address on the network
					given_ipaddr="${given_ip}/24"
					first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
					last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
					if [ "${given_ip}" != "${first_ip}" ]; then
						given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					else
						given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					fi
				else
					# Deduce the network settings from the given IP
					given_ip=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
					first_ip=$(ipcalc -s --no-decorate --minaddr "${given_ipaddr}")
					last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_ipaddr}")
					if [ "${given_ip}" != "${first_ip}" ]; then
						given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					else
						given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_ipaddr}")"
					fi
				fi
			else
				# With no valid given gateway, no default gateway and no given IP address, try to deduce everything from the search start IP address
				if [ -z "${given_startip}" ]; then
					if [ -n "${given_startipaddr}" ]; then
						autoderive_ip="true"
						# Derive everything from the given search start IP address
						given_startip=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
						first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
						last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
						if [ "${given_startip}" != "${first_ip}" ]; then
							given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
						else
							given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
						fi
					else
						# With no search start IP address there is nothing to deduce - simply restate the fact
						autoderive_ip="false"
					fi
				else
					autoderive_ip="true"
					# With no way to deduce a network prefix from the search start IP address, assume a class C network and apply it to the search start IP address
					given_startipaddr="${given_startip}/24"
					# Derive everything from the given search start IP address
					first_ip=$(ipcalc -s --no-decorate --minaddr "${given_startipaddr}")
					last_ip=$(ipcalc -s --no-decorate --maxaddr "${given_startipaddr}")
					if [ "${given_startip}" != "${first_ip}" ]; then
						given_gateway="${first_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
					else
						given_gateway="${last_ip}/$(ipcalc -s --no-decorate -p "${given_startipaddr}")"
					fi
				fi
			fi
		fi
	fi
fi

# Determine NIC bonding mode
given_bondmode=$(sed -n -e "s/^.*hvp_bondmode=\(\S*\).*$/\1/p" /proc/cmdline)
given_bondopts=$(sed -n -e "s/^.*hvp_bondopts=\(\S*\).*$/\1/p" /proc/cmdline)
if [ -n "${given_bondmode}" ]; then
	case "${given_bondmode}" in
		none|disable|skip)
			given_bondmode="none"
			;;
		lacp|lag|802.3ad)
			given_bondmode="lacp"
			if [ -z "${given_bondopts}" ]; then
				given_bondopts="mode=802.3ad;xmit_hash_policy=layer2+3;miimon=100"
			fi
			;;
		roundrobin|rr|balance-rr)
			given_bondmode="roundrobin"
			if [ -z "${given_bondopts}" ]; then
				given_bondopts="mode=balance-rr;miimon=100"
			fi
			;;
		activepassive|ap|active-backup)
			given_bondmode="activepassive"
			if [ -z "${given_bondopts}" ]; then
				given_bondopts="mode=active-backup;miimon=100"
			fi
			;;
		*)
			# In case of unrecognized mode force it empty 
			given_bondmode=""
			;;
	esac
fi
if [ -z "${given_bondmode}" ]; then
	if [ -n "${default_bondmode}" -a -n "${default_bondopts}" ]; then
		given_bondmode="${default_bondmode}"
		given_bondopts="${default_bondopts}"
	else
		given_bondmode="activepassive"
		given_bondopts="mode=active-backup;miimon=100"
	fi
fi

# Determine nameservers' addresses
# TODO: perform syntax/validity check
given_nameservers=$(sed -n -e "s/^.*hvp_nameservers=\(\S*\).*$/\1/p" /proc/cmdline)
if [ -z "${given_nameservers}" ]; then
	if [ -n "${default_nameservers}" ]; then
		given_nameservers="${default_nameservers}"
	else
		given_nameservers="1.1.1.1"
	fi
fi

# Determine NTP servers' addresses
# TODO: perform syntax/validity check
given_ntpservers=$(sed -n -e "s/^.*hvp_ntpservers=\(\S*\).*$/\1/p" /proc/cmdline)
if [ -z "${given_ntpservers}" ]; then
	if [ -n "${default_ntpservers}" ]; then
		given_ntpservers="${default_ntpservers}"
	fi
fi

# Detect/retrieve NetworkManager configuration
# Note: pre-provided NetworkManager configuration files are incompatible with dynamic network configuration discovery and will take precedence inhibiting it
# TODO: Support retrieval of vlan configuration files
# TODO: Support retrieval of arbitrarily stacked bonding/bridging/vlan configuration files
bond_masters=""
bridge_masters=""
found_fixed_conf="false"
mkdir -p ${local_igncfg_cache}/system-connections
# Detect fixed configuration based on NIC MAC address
# Note: only one .conf NetworkManager configuration fragment is supported
for nic_name in $(nmcli -g DEVICE device | grep -Ev '^(bond[0-9]|lo|sit[0-9])$' | sort); do
	nic_mac=$(nmcli -g GENERAL.HWADDR -e no device show "${nic_name}")
	if [ "${ign_fstype}" = "url" ]; then
		# Note: network-based NetworkManager configuration file retrieval autodetected
		echo "Attempting network retrieval of ${ign_dev}/${nic_mac}.nmconnection" 1>&2
		curl -o "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" -C - "${ign_dev}/${nic_mac}.nmconnection" || true
		echo "Attempting network retrieval of ${ign_dev}/${nic_mac}.conf" 1>&2
		curl -o "${local_igncfg_cache}/system-connections/custom.conf" -C - "${ign_dev}/${nic_mac}.conf" || true
	else
		# Note: filesystem-based NetworkManager configuration file retrieval autodetected
		echo "Attempting filesystem retrieval of ${ign_dev}/${nic_mac}.nmconnection" 1>&2
		cp -f "${ign_dev}/${nic_mac}.nmconnection" "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" || true
		echo "Attempting filesystem retrieval of ${ign_dev}/${nic_mac}.conf" 1>&2
		cp -f "${ign_dev}/${nic_mac}.conf" "${local_igncfg_cache}/system-connections/custom.conf" || true
	fi
	if [ -f "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" ]; then
		found_fixed_conf="true"
		# Detect bonding/bridging setup and prepare for retrieval of master device configuration
		slave_type=$(grep -o 'slave-type=.*$' "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" | sed -e 's/^.*slave-type=//')
		master=""
		case "${slave_type}" in
			"bond")
				master=$(grep -o 'master=.*$' "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" | sed -e 's/^.*master=//')
				if [ -n "${master}" ]; then
					bond_masters="${bond_masters} ${master}"
				else
					echo "Slave bonding device with no master configured - skipping bond configuration for ${nic_name}" 1>&2
				fi
				;;
			"bridge")
				master=$(grep -o 'master=.*$' "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" | sed -e 's/^.*master=//')
				if [ -n "${master}" ]; then
					bridge_masters="${bridge_masters} ${master}"
				else
					echo "Slave bridging device with no master configured - skipping bridge configuration for ${nic_name}" 1>&2
				fi
				;;
			*)
				echo "Plain device or unsupported slave type (detected: ${slave_type}) - skipping bond/bridge configuration for ${nic_name}" 1>&2
				;;
		esac
		if [ -n "${master}" ]; then
			mv "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection" "${local_igncfg_cache}/system-connections/${master}-slave-${nic_name}.nmconnection"
		fi
	fi
done
# Detect fixed configuration based on bonding
for nic_name in $(nmcli -g DEVICE device | grep -Ev '^(bond[0-9]|lo|sit[0-9])$' | sort); do
	nic_mac=$(nmcli -g GENERAL.HWADDR -e no device show "${nic_name}")
	for master in ${bond_masters} ${bridge_masters}; do
		if [ -f "${local_igncfg_cache}/system-connections/${master}-slave-${nic_name}.nmconnection" -a ! -f "${local_igncfg_cache}/system-connections/${master}.nmconnection" ]; then
			if [ "${ign_fstype}" = "url" ]; then
				# Note: network-based NetworkManager configuration file retrieval autodetected
				echo "Attempting network retrieval of ${ign_dev}/${nic_mac}-${master}.nmconnection" 1>&2
				curl -o "${local_igncfg_cache}/system-connections/${master}.nmconnection" -C - "${ign_dev}/${nic_mac}-${master}.nmconnection" || true
			else
				# Note: filesystem-based NetworkManager configuration file retrieval autodetected
				echo "Attempting filesystem retrieval of ${ign_dev}/${nic_mac}-${master}.nmconnection" 1>&2
				cp -f "${ign_dev}/${nic_mac}-${master}.nmconnection" "${local_igncfg_cache}/system-connections/${master}.nmconnection" || true
			fi
		fi
	done
done
# Set network parameters from retrieved fixed configuration
if [ "${found_fixed_conf}" = "true" ]; then
	for nm_cfg_file in ${local_igncfg_cache}/system-connections/*.nmconnection ; do
		# Support multiple configured NICs - select the first with a default gateway on it
		if [ -s "${nm_cfg_file}" ]; then
			if grep -Eq "address1=${IPregex}/[[:digit:]]+,${IPregex}" "${nm_cfg_file}" ; then
				break
			fi
		fi
	done
	assigned_ipaddr=$(grep 'address1=' "${nm_cfg_file}" | sed -e 's>^\s*address1=\([^/]*\)/.*$>\1>')
	network_prefix=$(grep 'address1=' "${nm_cfg_file}" | sed -e 's>^\s*address1=[^/]*/\([^;]*\);.*$>\1>')
	gateway_address=$(grep 'address1=' "${nm_cfg_file}" | sed -e 's>^\s*address1=[^/]*/[^;]*;\(.*\\))$>\1>')
	main_interface=$(basename "$(grep -H 'address1=' "${nm_cfg_file}" | sed -e 's/^\([^:]*\):.*$/\1/')" ".nmconnection")
	first_address=$(ipcalc -s --no-decorate --minaddr "${gateway_address}/${network_prefix}")
	addresses_to_try=$(ipcalc -s --no-decorate --addresses "${gateway_address}/${network_prefix}")
fi

# Dynamically detect network configuration
# TODO: support dynamic autodetection of arbitrarily stacked bond/bridge/vlan configurations
autodetected_network_conf="false"
if [ "${found_fixed_conf}" = "false" ]; then
	if [ -n "${given_ipaddr}" -o "${autoderive_ip}" = "true" ]; then
		echo "Autodetecting network configuration" 1>&2
		autodetected_network_conf="true"
		# Disable any interface configured by NetworkManager
		# Note: NetworkManager autodetected configuration may interfer with the autoconfiguration logic
		# Note: NetworkManager device names do not contain spaces
		echo "Cleaning up current network configuration" 1>&2
		for nic_device_name in $(nmcli -g DEVICE -e no device | grep -Ev '^(bond[0-9]|lo|sit[0-9])$' | sort); do
			if nmcli -g GENERAL.STATE -e no device show "${nic_device_name}" | grep -Ewq '(connected|connecting)' ; then
				nmcli -w 30 device disconnect "${nic_device_name}"
				ip addr flush dev "${nic_device_name}"
			fi
		done
		udevadm settle --timeout=30
		# Note: using UUID to identify NetworkManager connections since the connection names may contain spaces
		for connection_id in $(nmcli -g UUID,TYPE -e no connection show | awk -F: '{if ($2 != "loopback") print $1}' | sort); do
			nmcli -w 30 connection delete "${connection_id}"
		done
		udevadm settle --timeout=30
		# Cycle on NICs with carrier on and configure with the given bonding mode or as a plain interface
		# For each configured NIC try attaching the given IP or discover an available IP on the gateway network and check whether configuration succeeds
		# For each successful IPc configuration check whether the gateway IP is reachable (verifies whether the interface is connected to the right LAN)
		managed_nics=""
		unmanaged_nics=""
		network_prefix=$(ipcalc -s --no-decorate -p "${given_gateway}")
		gateway_address=$(ipcalc -s --no-decorate -a "${given_gateway}")
		minimum_address=$(ipcalc -s --no-decorate --minaddr "${given_gateway}")
		maximum_address=$(ipcalc -s --no-decorate --maxaddr "${given_gateway}")
		# Define the search start IP address and range
		if [ -n "${given_startipaddr}" ]; then
			# If a specific search start IP address has been specified then start from that one
			first_address=$(ipcalc -s --no-decorate -a "${given_startipaddr}")
		else
			# Otherwise start from the minimum address on the network
			first_address="${minimum_address}"
		fi
		# Derive the largest range of addresses to try between the start address and the last address
		available_addresses=$(ipdiff "${maximum_address}" "${first_address}")
		if [ -n "${given_rangeipaddr}" ]; then
			if [ ${given_rangeipaddr} -lt ${available_addresses} ]; then
				# If a smaller range has been specified then limit search to that range
				addresses_to_try="${given_rangeipaddr}"
			else
				# Otherwise go up to maximum address on the network
				addresses_to_try="${available_addresses}"
			fi
		else
			addresses_to_try="${available_addresses}"
		fi
		echo "Testing IP addresses from ${first_address} with a range of ${addresses_to_try} IPs and gateway ${gateway_address}/${network_prefix}" 1>&2
		# If bonding mode is not none, configure a proper bonding master
		if [ "${given_bondmode}" != "none" ]; then
			bond_name="bond0"
			connection_name="bond0"
			nmcli connection add type bond con-name "${connection_name}" ifname "${bond_name}" bond.options "$(echo "${given_bondopts}" | sed -e 's/;/,/g')"
			udevadm settle --timeout=30
		fi
		# If the IP address is explicitly assigned note it
		if [ -n "${given_ipaddr}" ]; then
			assigned_ipaddr=$(ipcalc -s --no-decorate -a "${given_ipaddr}")
		else
			assigned_ipaddr=""
		fi
		for device in $(nmcli -g DEVICE,STATE -e no device | sed -e 's/\s.*$//g') ; do
			nic_name=$(echo "${device}" | awk -F: '{print $1}')
			nic_status=$(echo "${device}" | awk -F: '{print $2}')
			# Skip the loopback etc. devices
			if echo "${nic_name}" | grep -Eq '^(bond[0-9]|lo|sit[0-9])$' ; then
				echo "Skipping out-of-scope NIC ${nic_name}" 1>&2
				continue
			fi
			# If a NIC has already been assigned and the bonding mode is none then skip all the other NICs
			if [ -n "${managed_nics}" -a "${given_bondmode}" = "none" ]; then
				unmanaged_nics="${unmanaged_nics} ${nic_name}"
				echo "Skipping redundant NIC ${nic_name}" 1>&2
				continue
			fi
			nic_assigned='false'
			# Note: the status will contain "connected" for link up (or "connecting" if DHCP server is still not responding), "unavailable" for link down or "disconnected" for link up but interface disabled
			if [ "${nic_status}" != "unavailable" ]; then
				# Configure the NIC either as a plain interface or as a slave of the bonding master above
				if [ "${given_bondmode}" != "none" ]; then
					connection_name="${bond_name}-${nic_name}"
					nmcli connection add type ethernet slave-type bond con-name "${connection_name}" ifname "${nic_name}" master "${bond_name}"
					ip_connection_name="${bond_name}"
				else
					connection_name="${nic_name}"
					nmcli connection add type ethernet con-name "${connection_name}" ifname "${nic_name}"
					ip_connection_name="${nic_name}"
				fi
				udevadm settle --timeout=30
				if [ -z "${assigned_ipaddr}" ]; then
					# Cycle on all possible IPs to find the first one whose configuration succeeds on the plain interface / bond
					for index in $(seq 0 $((addresses_to_try - 1))) ; do
						tentative_ipaddr=$(ipmat ${first_address} ${index} +)
						# Skip gateway IP address
						if [ "${tentative_ipaddr}" = "${gateway_address}" ]; then
							echo "Skipping gateway IP address ${tentative_ipaddr}" 1>&2
							continue
						fi
						res1=0
						nmcli connection modify "${ip_connection_name}" ipv4.method manual ipv4.addresses "${tentative_ipaddr}/${network_prefix}" ipv4.gateway "${gateway_address}" ipv4.dns "$(echo "${given_nameservers}" | sed -e 's/,/ /g')" || res1=1
						res2=0
						# Note: activating a bond slave automatically activates also the master
						nmcli -w 30 connection up "${connection_name}" || res2=1
						if [ ${res1} -ne 0 -o ${res2} -ne 0 ]; then
							# There has been a problem in assigning the IP address - skip this IP address
							echo "Skipping failed IP address ${tentative_ipaddr} on NIC ${nic_name} (res1:${res1} / res2:${res2})" 1>&2
							tentative_ipaddr=""
							continue
						else
							echo "Trying IP address ${tentative_ipaddr} on NIC ${nic_name}" 1>&2
							break
						fi
					done
				else
					# Directly apply the given assigned IP
					tentative_ipaddr="${assigned_ipaddr}"
					res1=0
					nmcli connection modify "${ip_connection_name}" ipv4.method manual ipv4.addresses "${tentative_ipaddr}/${network_prefix}" ipv4.gateway "${gateway_address}" ipv4.dns "$(echo "${given_nameservers}" | sed -e 's/,/ /g')" || res1=1
					res2=0
					# Note: activating a bond slave automatically activates also the master
					nmcli -w 30 connection up "${connection_name}" || res2=1
					if [ ${res1} -ne 0 -o ${res2} -ne 0 ]; then
						# There has been a problem in assigning the IP address - skip this NIC
						unmanaged_nics="${unmanaged_nics} ${nic_name}"
						nmcli -w 30 connection delete "${connection_name}"
						udevadm settle --timeout=30
						echo "Skipping failed IP address activation for given IP ${tentative_ipaddr} on NIC ${nic_name} (res1:${res1} / res2:${res2})" 1>&2
						continue
					else
						echo "Trying given IP address ${tentative_ipaddr} on NIC ${nic_name}" 1>&2
					fi
				fi
				if [ -n "${tentative_ipaddr}" ]; then
					# Note: adding extra sleep and ping to work around possible hardware delays
					sleep 2
					ping -c 3 -w 8 -i 2 "${gateway_address}" > /dev/null 2>&1 || true
					res=0
					ping -c 3 -w 8 -i 2 "${gateway_address}" > /dev/null 2>&1 || res=1
					if [ ${res} -eq 0 ]; then
						managed_nics="${managed_nics} ${nic_name}"
						nic_assigned='true'
						echo "Verified IP ${tentative_ipaddr} on NIC ${nic_name}" 1>&2
					else
						echo "Failed verifying IP ${tentative_ipaddr} on NIC ${nic_name} (res:${res})" 1>&2
					fi
				fi
				if [ "${nic_assigned}" = "false" ]; then
					# Disable NICs whose assignment failed
					unmanaged_nics="${unmanaged_nics} ${nic_name}"
					echo "Skipping failed NIC ${nic_name}" 1>&2
				else
					assigned_ipaddr="${tentative_ipaddr}"
					echo "Confirmed IP ${tentative_ipaddr} while testing on NIC ${nic_name}" 1>&2
				fi
			else
				# Disable unconnected NICs and try with the next one
				unmanaged_nics="${unmanaged_nics} ${nic_name}"
				echo "Skipping unconnected NIC ${nic_name}" 1>&2
				continue
			fi
			# Remove a plain interface if unsuccessful or a bond slave anyway (in order to allow verifying the connection using exclusively a different NIC as slave)
			if [ "${given_bondmode}" != "none" -o "${nic_assigned}" = "false" ]; then
				nmcli -w 30 connection delete "${connection_name}"
				udevadm settle --timeout=30
			fi
		done
		# Whenever a NIC is marked as unmanaged add it to a dedicated NetworkManager configuration fragment
		if [ -n "${unmanaged_nics}" ]; then
			nm_configuration_line="unmanaged-devices="
			for nic_name in ${unmanaged_nics} ; do
				# Use the MAC address as a stable way to identify unmanaged NICs
				nic_mac=$(nmcli -g GENERAL.HWADDR -e no device show "${nic_name}")
				nm_configuration_line="${nm_configuration_line}mac:${nic_mac};"
			done
			nm_configuration_line=$(echo "${nm_configuration_line}" | sed -e 's/;$//')
			cat <<- EOF > ${local_igncfg_cache}/system-connections/99-unmanaged-devices.conf
			[keyfile]
			${nm_configuration_line}
			EOF
		fi
		# Save the derived final configuration (including bonding masters) as .nmconnection files
		if [ "${given_bondmode}" != "none" ]; then
			main_interface="${bond_name}"
			# Create the bond master configuration file
			cat <<- EOF > "${local_igncfg_cache}/system-connections/${bond_name}.nmconnection"
			[connection]
			id=${bond_name}
			uuid=$(uuidgen)
			type=bond
			interface-name=${bond_name}
			
			[bond]
			
			[ipv4]
			address1=${assigned_ipaddr}/${network_prefix},${gateway_address}
			dns=$(echo "${given_nameservers}" | sed -e 's/,/;/g');
			dns-search=${given_domainname};
			may-fail=false
			method=manual
				
			[ipv6]
			addr-gen-mode=stable-privacy
			method=ignore
			never-default=true
			
			[proxy]
			EOF
			# Add bonding opts parameters
			sed -i -e "s/^\[bond\].*\$/[bond]\\n$(echo "${given_bondopts}" | sed -e 's/;/\\n/g')/" "${local_igncfg_cache}/system-connections/${bond_name}.nmconnection"
		fi
		for nic_name in ${managed_nics} ; do
			nic_mac=$(nmcli -g GENERAL.HWADDR -e no device show "${nic_name}")
			if [ "${given_bondmode}" != "none" ]; then
				# Create bond slave configuration file
				cat <<- EOF > "${local_igncfg_cache}/system-connections/${bond_name}-slave-${nic_name}.nmconnection"
				[connection]
				id=${bond_name}-slave-${nic_name}
				uuid=$(uuidgen)
				type=ethernet
				master=${bond_name}
				slave-type=bond
				
				[ethernet]
				mac-address=${nic_mac}
				EOF
			else
				main_interface="${nic_name}"
				# Create plain interface configuration file
				cat <<- EOF > "${local_igncfg_cache}/system-connections/${nic_name}.nmconnection"
				[connection]
				id=${nic_name}
				uuid=$(uuidgen)
				type=ethernet
				interface-name=${nic_name}
				
				[ethernet]
				mac-address=${nic_mac}
				
				[ipv4]
				address1=${assigned_ipaddr}/${network_prefix},${gateway_address}
				dns=$(echo "${given_nameservers}" | sed -e 's/,/;/g');
				dns-search=${given_domainname};
				may-fail=false
				method=manual
				
				[ipv6]
				addr-gen-mode=stable-privacy
				method=ignore
				never-default=true
				
				[proxy]
				EOF
			fi
		done
	fi
fi
# Support enforcing immediately (before installation) the NetworkManager fixed configuration retrieved above
# Note: Dynamically detected NetworkManager configuration is also unconditionally and automatically enforced here anyway since it happens with no regard for the final state of the network
if [ "${given_enactnmconf}" = "true" -a "${found_fixed_conf}" = "true" -o "${autodetected_network_conf}" = "true" ]; then
	echo "Immediately enacting detected/retrieved NetworkManager configuration" 1>&2
	# Disable any interface configured by NetworkManager then stop the service
	# Note: NetworkManager autodetected configuration may interfer with the configuration detected/retrieved above
	# Note: interfaces will be explicitly activated again by the configuration detected/retrieved above
	# Note: NetworkManager device names do not contain spaces
	for nic_device_name in $(nmcli -g DEVICE device | grep -Ev '^(bond[0-9]|lo|sit[0-9])$' | sort); do
		if nmcli -g GENERAL.STATE -e no device show "${nic_device_name}" | grep -Ewq '(connected|connecting)' ; then
			nmcli -w 30 device disconnect "${nic_device_name}"
			ip addr flush dev "${nic_device_name}"
		fi
	done
	udevadm settle --timeout=30
	# Note: using UUID to identify NetworkManager connections since the names may contain spaces
	for connection_id in $(nmcli -g UUID,TYPE -e no connection show | awk -F: '{if ($2 != "loopback") print $1}' | sort); do
		nmcli -w 30 connection delete "${connection_id}"
	done
	udevadm settle --timeout=30
	systemctl stop NetworkManager
	# Copy the NetworkManager configuration previously detected/determined then start again the service
	for nm_conn_file in ${local_igncfg_cache}/system-connections/*.nmconnection ; do
		if [ -f "${nm_conn_file}" ]; then
			nm_conn_file_basename=$(basename "${nm_conn_file}")
			cp "${nm_conn_file}" "/etc/NetworkManager/system-connections/${nm_conn_file_basename}"
			chown root:root "/etc/NetworkManager/system-connections/${nm_conn_file_basename}"
			chmod 600 "/etc/NetworkManager/system-connections/${nm_conn_file_basename}"
		fi
	done
	for nm_conf_file in ${local_igncfg_cache}/system-connections/*.conf ; do
		if [ -f "${nm_conf_file}" ]; then
			nm_conf_file_basename=$(basename "${nm_conf_file}")
			cp "${nm_conf_file}" "/etc/NetworkManager/conf.d/${nm_conf_file_basename}"
			chown root:root "/etc/NetworkManager/conf.d/${nm_conf_file_basename}"
			chmod 644 "/etc/NetworkManager/conf.d/${nm_conf_file_basename}"
		fi
	done
	systemctl start NetworkManager
fi

# Set network parameters from externally-induced automatic (DHCP) configuration
# Note: it is assumed that somehow (DHCP reservations?) the configuration is stable
# TODO: add support for IPv6
if [ "${found_fixed_conf}" = "false"  -a "${autodetected_network_conf}" = "false" ]; then
	gateway_address=$(ip route show to default | awk '{print $4}')
	main_interface=$(ip route show to default | awk '{print $6}')
	assigned_ipaddr=$(ip address show dev ${main_interface} | awk '/inet / {print $2}' | sed -e 's>^([^/]*\)/.*$>\1>')
	network_prefix=$(ip address show dev ${main_interface} | awk '/inet / {print $2}' | sed -e 's>^[^/]*/\(.*\)$>\1>')
	first_address=$(ipcalc -s --no-decorate --minaddr "${gateway_address}/${network_prefix}")
	addresses_to_try=$(ipcalc -s --no-decorate --addresses "${gateway_address}/${network_prefix}")
fi

# Determine embedded/layered packages, services and kernel arguments
given_removepkgs=$(sed -n -e 's/^.*hvp_removepkgs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_replacepkgs=$(sed -n -e 's/^.*hvp_replacepkgs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_addpkgs=$(sed -n -e 's/^.*hvp_addpkgs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_removekargs=$(sed -n -e 's/^.*hvp_removekargs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_replacekargs=$(sed -n -e 's/^.*hvp_replacekargs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_addkargs=$(sed -n -e 's/^.*hvp_addkargs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_masksvcs=$(sed -n -e 's/^.*hvp_masksvcs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_disablesvcs=$(sed -n -e 's/^.*hvp_disablesvcs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
given_enablesvcs=$(sed -n -e 's/^.*hvp_enablesvcs=\(\S*\).*$/\1/p' /proc/cmdline | sed -e 's/,/ /g')
if [ "${given_removepkgs}" = '""' -o "${given_removepkgs}" = "''" ]; then
	given_removepkgs=""
elif [ -z "${given_removepkgs}" ]; then
	if [ -n "${default_removepkgs}" ]; then
		given_removepkgs="${default_removepkgs}"
	fi
fi
if [ "${given_replacepkgs}" = '""' -o "${given_replacepkgs}" = "''" ]; then
	given_replacepkgs=""
elif [ -z "${given_replacepkgs}" ]; then
	if [ -n "${default_replacepkgs}" ]; then
		given_replacepkgs="${default_replacepkgs}"
	fi
fi
if [ "${given_addpkgs}" = '""' -o "${given_addpkgs}" = "''" ]; then
	given_addpkgs=""
elif [ -z "${given_addpkgs}" ]; then
	if [ -n "${default_addpkgs}" ]; then
		given_addpkgs="${default_addpkgs}"
	fi
fi
if [ "${given_removekargs}" = '""' -o "${given_removekargs}" = "''" ]; then
	given_removekargs=""
elif [ -z "${given_removekargs}" ]; then
	if [ -n "${default_removekargs}" ]; then
		given_removekargs="${default_removekargs}"
	fi
fi
if [ "${given_replacekargs}" = '""' -o "${given_replacekargs}" = "''" ]; then
	given_replacekargs=""
elif [ -z "${given_replacekargs}" ]; then
	if [ -n "${default_replacekargs}" ]; then
		given_replacekargs="${default_replacekargs}"
	fi
fi
if [ "${given_addkargs}" = '""' -o "${given_addkargs}" = "''" ]; then
	given_addkargs=""
elif [ -z "${given_addkargs}" ]; then
	if [ -n "${default_addkargs}" ]; then
		given_addkargs="${default_addkargs}"
	fi
fi
if [ "${given_masksvcs}" = '""' -o "${given_masksvcs}" = "''" ]; then
	given_masksvcs=""
elif [ -z "${given_masksvcs}" ]; then
	if [ -n "${default_masksvcs}" ]; then
		given_masksvcs="${default_masksvcs}"
	fi
fi
if [ "${given_disablesvcs}" = '""' -o "${given_disablesvcs}" = "''" ]; then
	given_disablesvcs=""
elif [ -z "${given_disablesvcs}" ]; then
	if [ -n "${default_disablesvcs}" ]; then
		given_disablesvcs="${default_disablesvcs}"
	fi
fi
if [ "${given_enablesvcs}" = '""' -o "${given_enablesvcs}" = "''" ]; then
	given_enablesvcs=""
elif [ -z "${given_enablesvcs}" ]; then
	if [ -n "${default_enablesvcs}" ]; then
		given_enablesvcs="${default_enablesvcs}"
	fi
fi

# Determine admin username, password hash and SSH public key
given_admin_username="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_adminname=\(\S*\).*$/\1/p')"
if [ -z "${given_admin_username}" ]; then
	if [ -n "${default_admin_username}" ]; then
		given_admin_username="${default_admin_username}"
	else
		given_admin_username="hvpadmin"
	fi
fi
given_admin_password="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_adminpwd=\(\S*\).*$/\1/p')"
if [ -z "${given_admin_password}" ]; then
	if [ -n "${default_admin_password}" ]; then
		given_admin_password="${default_admin_password}"
	else
		given_admin_password='$6$EngnSSn5$DiapvymRZ579Tt6pNBgRwT7D7PTDzWkT3ffKUO1U1qMloraFsg7jI6WfdM1oddxDvW9AFmBMKNOG1ylW7KiFU.'
	fi
fi
given_admin_sshpubkey="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_adminsshpubkey=\(\S*\).*$/\1/p')"
if [ -z "${given_admin_sshpubkey}" ]; then
	if [ -n "${default_admin_sshpubkey}" ]; then
		given_admin_sshpubkey="${default_admin_sshpubkey}"
	else
		given_admin_sshpubkey='ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBABuG9cJmQajdDokyk0C/v2bla9Z5TPJTBU0iLVQMyyUbvP+NHb0TKN3Mwex+M0bPA+LVEbgj+6gWw+yf/8CR3p3hACiiEu4qgFihXJdP69DBCv2zU/noDj6xN08m3+P9iwK/YdxQ4q2EpAqVX7B+r1sYypttXrUF64R0vLXoz6+WtQOdQ== root@twilight.mgmt.private'
	fi
fi

# Perform parameter substitution inside custom Ignition file
# Note: performing escape on password hash and SSH public key
if [ -s ${local_igncfg_cache}/$(basename "${given_ign_source}") ]; then
	/usr/bin/sed -i --follow-symlinks \
		-e "s/__HVP_ADMIN_USERNAME_HVP__/${given_admin_username}/g" \
		-e "s/__HVP_ADMIN_PASSWORD_HASH_HVP__/$(echo "${given_admin_password}" | sed -e 's/[&/\]/\\&/g')/g" \
		-e "s/__HVP_ADMIN_SSH_PUBKEY_HVP__/$(echo "${given_admin_sshpubkey}" | sed -e 's/[&/\]/\\&/g')/g" \
	${local_igncfg_cache}/$(basename "${given_ign_source}")
fi

echo "pre-hook script version ${pre_version} exiting"

