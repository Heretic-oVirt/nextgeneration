# Script sourced immediately after the embedded Fedora CoreOS installer invocation has been completed
# Note: to influence timezone add hvp_timezone=XXX where XXX is one of the timezones available in /usr/share/zoneinfo/
# Note: to influence hostname assignment logic add hvp_hostname_assignment=YYY where YYY is one of fixed, automated
# Note: to influence hostname add hvp_hostname=ZZZ where ZZZ becomes either the full hostname or the prefix, depending on the assignment logic selected (use "" or '' to explicitly force it to the empty string, obtaining either the builtin CoreOS default or a non-prefixed automated hostname)
# Note: to influence keyboard layout add hvp_kblayout=TT where TT is one of the keyboard maps available in /usr/lib/kbd/keymaps/xkb/ 
# Note: to influence node type add hvp_nodetype=UU where UU is a custom qualifier (values depend on installation type and are managed by the provided post_install_hook_custom_actions function)
# Note: to influence embedded package removal logic add hvp_removepkgs=XXX where XXX is a comma-separated list of package names present by default and to be removed (use "" or '' to explicitly set it to the empty list)
# Note: to influence embedded package replacement logic add hvp_replacepkgs=XXX where XXX is a comma-separated list of package names present by default and to be replaced (use "" or '' to explicitly set it to the empty list)
# Note: to influence package addition logic add hvp_addpkgs=XXX where XXX is a comma-separated list of package names to be installed (use "" or '' to explicitly set it to the empty list)
# Note: to influence embedded kernel argument removal logic add hvp_removekargs=XXX where XXX is a comma-separated list of kernel arguments present by default and to be removed (use "" or '' to explicitly set it to the empty list)
# Note: to influence embedded kernel argument replacement logic add hvp_replacekargs=XXX where XXX is a comma-separated list of kernel arguments present by default and to be replaced (use "" or '' to explicitly set it to the empty list)
# Note: to influence kernel argument addition logic add hvp_addkargs=XXX where XXX is a comma-separated list of kernel arguments to be installed (use "" or '' to explicitly set it to the empty list)
# Note: to influence service masking logic add hvp_masksvcs=XXX where XXX is a comma-separated list of unit names to be masked (use "" or '' to explicitly set it to the empty list)
# Note: to influence service disabling logic add hvp_disablesvcs=XXX where XXX is a comma-separated list of unit names to be disabled (use "" or '' to explicitly set it to the empty list)
# Note: to influence service enabling logic add hvp_enablesvcs=XXX where XXX is a comma-separated list of unit names to be enabled (use "" or '' to explicitly set it to the empty list)

post_version="2024070903"

echo "post-hook script version ${post_version} starting"

# Wait for installation-induced storage reconfiguration events to settle
kpartx -uvs "/dev/${nodeosdisk_device_name}"
udevadm settle --timeout=60

# Detect OSTree installation path
mount /dev/disk/by-label/boot /mnt
ostree_path=$(grep -o 'ostree=[^[:space:]]*' /mnt/loader/entries/ostree-1*.conf | sed -e 's>^ostree=>>')
umount /mnt

# Mount target installation
mount /dev/disk/by-label/root /mnt

# Set system timezone
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
if [ -s "/mnt/${ostree_path}/usr/share/zoneinfo/${given_timezone}" ]; then
	ln -sf "../usr/share/zoneinfo/${given_timezone}" "/mnt/${ostree_path}/etc/localtime"
else
	echo "Unspecified/invalid/unsupported timezone ${given_timezone} - skipping" 1>&2
fi

# TODO: Set domain name

# Set system hostname
# TODO: add domain name to create a FQDN as hostname
given_hostname_assignment="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_hostname_assignment=\(\S*\).*$/\1/p')"
if [ -z "${given_hostname_assignment}" ]; then
	if [ -n "${default_hostname_assignment}" ]; then
		given_hostname_assignment="${default_hostname_assignment}"
	else
		given_hostname_assignment="fixed"
	fi
fi
given_hostname="$(cat /proc/cmdline | sed -n -e 's/^.*hvp_hostname=\(\S*\).*$/\1/p')"
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
fi
if [ "${given_hostname_assignment}" = "fixed" ]; then
	if [ -n "${given_hostname}" ]; then
		echo "${given_hostname}" > "/mnt/${ostree_path}/etc/hostname"
	fi
else
	if [ -n "${given_hostname}" ]; then
		echo -n "${given_hostname}-" > "/mnt/${ostree_path}/etc/hostname"
	fi
	tr -d " .,_:-" < /sys/class/dmi/id/product_serial >> "/mnt/${ostree_path}/etc/hostname"
fi

# Set system keyboard layout
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
if [ -s "/mnt/${ostree_path}/usr/lib/kbd/keymaps/xkb/${given_kblayout}.map.gz" ]; then
	echo "Configuring keyboard layout ${given_kblayout}" 1>&2
	echo "KEYMAP=${given_kblayout}" > "/mnt/${ostree_path}/etc/vconsole.conf"
	chown root:root "/mnt/${ostree_path}/etc/vconsole.conf"
	chmod 644 "/mnt/${ostree_path}/etc/vconsole.conf"
else
	echo "Unspecified/invalid/unsupported keyboard layout ${given_kblayout} - skipping" 1>&2
fi

# Configure NetworkManager
# TODO: Support creation of NetworkManager custom configuration files from given variables and network discovery
# TODO: Support retrieval of vlan configuration files
# TODO: Support retrieval of arbitrarily stacked bonding/bridging/vlan configuration files
bond_masters=""
bridge_masters=""
for nic_name in $(ls /sys/class/net/ 2>/dev/null | grep -Ev '^(bonding_masters|lo|sit[0-9])$' | sort); do
	nic_mac=$(sed -e 's/:-//g' /sys/class/net/${nic_name}/address)
	if [ "${ign_fstype}" = "url" ]; then
		# Note: network-based NetworkManager configuration file retrieval autodetected
		echo "Attempting network retrieval of ${ign_dev}/${nic_mac}.nmconnection" 1>&2
		curl -o "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" -C - "${ign_dev}/${nic_mac}.nmconnection" || true
	else
		# Note: filesystem-based NetworkManager configuration file retrieval autodetected
		echo "Attempting filesystem retrieval of ${ign_dev}/${nic_mac}.nmconnection" 1>&2
		cp -f "${ign_dev}/${nic_mac}.nmconnection" "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" || true
	fi
	if [ -f "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" ]; then
		chown root:root "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection"
		chmod 600 "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection"
		# Detect bonding/bridging setup and prepare for retrieval of master device configuration
		slave_type=$(grep -o 'slave-type=.*$' "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" | sed -e 's/^.*slave-type=//')
		master=""
		case "${slave_type}" in
			"bond")
				master=$(grep -o 'master=.*$' "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" | sed -e 's/^.*master=//')
				if [ -n "${master}" ]; then
					bond_masters="${bond_masters} ${master}"
				else
					echo "Slave bonding device with no master configured - skipping bond configuration for ${nic_name}" 1>&2
				fi
				;;
			"bridge")
				master=$(grep -o 'master=.*$' "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" | sed -e 's/^.*master=//')
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
			mv "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nic_name}.nmconnection" "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}-slave-${nic_name}.nmconnection"
		fi
	fi
done
for nic_name in $(ls /sys/class/net/ 2>/dev/null | grep -Ev '^(bonding_masters|lo|sit[0-9])$' | sort); do
	nic_mac=$(sed -e 's/:-//g' /sys/class/net/${nic_name}/address)
	for master in ${bond_masters} ${bridge_masters}; do
		if [ -f "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}-slave-${nic_name}.nmconnection" -a ! -f "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}.nmconnection" ]; then
			if [ "${ign_fstype}" = "url" ]; then
				# Note: network-based NetworkManager configuration file retrieval autodetected
				echo "Attempting network retrieval of ${ign_dev}/${nic_mac}-${master}.nmconnection" 1>&2
				curl -o "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}.nmconnection" -C - "${ign_dev}/${nic_mac}-${master}.nmconnection" || true
			else
				# Note: filesystem-based NetworkManager configuration file retrieval autodetected
				echo "Attempting filesystem retrieval of ${ign_dev}/${nic_mac}-${master}.nmconnection" 1>&2
				cp -f "${ign_dev}/${nic_mac}-${master}.nmconnection" "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}.nmconnection" || true
			fi
			if [ -f "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}.nmconnection" ]; then
				chown root:root "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}.nmconnection"
				chmod 600 "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${master}.nmconnection"
			fi
		fi
	done
done

# Configure embedded/layered packages, services and kernel arguments
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
	given_removepkgs="${default_removepkgs}"
fi
if [ "${given_replacepkgs}" = '""' -o "${given_replacepkgs}" = "''" ]; then
	given_replacepkgs=""
elif [ -z "${given_replacepkgs}" ]; then
	given_replacepkgs="${default_replacepkgs}"
fi
if [ "${given_addpkgs}" = '""' -o "${given_addpkgs}" = "''" ]; then
	given_addpkgs=""
elif [ -z "${given_addpkgs}" ]; then
	given_addpkgs="${default_addpkgs}"
fi
if [ "${given_removekargs}" = '""' -o "${given_removekargs}" = "''" ]; then
	given_removekargs=""
elif [ -z "${given_removekargs}" ]; then
	given_removekargs="${default_removekargs}"
fi
if [ "${given_replacekargs}" = '""' -o "${given_replacekargs}" = "''" ]; then
	given_replacekargs=""
elif [ -z "${given_replacekargs}" ]; then
	given_replacekargs="${default_replacekargs}"
fi
if [ "${given_addkargs}" = '""' -o "${given_addkargs}" = "''" ]; then
	given_addkargs=""
elif [ -z "${given_addkargs}" ]; then
	given_addkargs="${default_addkargs}"
fi
if [ "${given_masksvcs}" = '""' -o "${given_masksvcs}" = "''" ]; then
	given_masksvcs=""
elif [ -z "${given_masksvcs}" ]; then
	given_masksvcs="${default_masksvcs}"
fi
if [ "${given_disablesvcs}" = '""' -o "${given_disablesvcs}" = "''" ]; then
	given_disablesvcs=""
elif [ -z "${given_disablesvcs}" ]; then
	given_disablesvcs="${default_disablesvcs}"
fi
if [ "${given_enablesvcs}" = '""' -o "${given_enablesvcs}" = "''" ]; then
	given_enablesvcs=""
elif [ -z "${given_enablesvcs}" ]; then
	given_enablesvcs="${default_enablesvcs}"
fi
# Add configuration file required by layered-packages-kargs.service
cat << EOF > "/mnt/${ostree_path}/etc/sysconfig/layered-packages-kargs"
# Modify packages and dependencies
REMOVE_RPM_PACKAGES="${given_removepkgs}"
REPLACE_RPM_PACKAGES="${given_replacepkgs}"
ADD_RPM_PACKAGES="${given_addpkgs}"
# Modify kernel commandline arguments
REMOVE_KARGS="${given_removekargs}"
REPLACE_KARGS="${given_replacekargs}"
ADD_KARGS="${given_addkargs}"
# Mask/disable/enable units
MASK_UNITS="${given_masksvcs}"
DISABLE_UNITS="${given_disablesvcs}"
ENABLE_UNITS="${given_enablesvcs}"
EOF
chown root:root "/mnt/${ostree_path}/etc/sysconfig/layered-packages-kargs"
chmod 644 "/mnt/${ostree_path}/etc/sysconfig/layered-packages-kargs"

# Disable weak dependencies
# Note: this is supported starting from rpm-ostree v2024.6
echo 'Recommends=false' >> "/mnt/${ostree_path}/etc/rpm-ostreed.conf"

# Invoke custom post-install actions if defined
# Note: the post_install_hook_custom_actions function must have been defined by means of the dynamically retrieved configuration fragments
post_install_hook_custom_actions || true

# Unmount target installation
umount /mnt

# Conditionally reboot (may be inhibited to help debugging installation issues)
if ! grep -qw 'skip_reboot' /proc/cmdline ; then
	echo "post-hook script version ${post_version} rebooting machine"
	systemctl --no-block reboot
else
	echo "Skipping reboot" 1>&2
fi

echo "post-hook script version ${post_version} exiting"
