# Script sourced immediately after the embedded Fedora CoreOS installer invocation has been completed

post_version="2025010601"

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

# Invoke custom post-install actions if defined
# Note: the post_install_hook_custom_actions function must have been defined by means of the dynamically retrieved configuration fragments
# Note: the post_install_hook_custom_actions function is invoked here after installation has been completed and the installation filesystem has been mounted but before any customization action has been performed
# Note: it is assumed that the post-install hook script will make available to the post_install_hook_custom_actions function the following additional variables:
# post_version
# ostree_path
post_install_hook_custom_actions || true

# Set system timezone
if [ -n "${given_timezone}" -a -s "/mnt/${ostree_path}/usr/share/zoneinfo/${given_timezone}" ]; then
	ln -sf "../usr/share/zoneinfo/${given_timezone}" "/mnt/${ostree_path}/etc/localtime"
else
	echo "Unspecified/invalid/unsupported timezone '${given_timezone}' - skipping" 1>&2
fi

# Set system keyboard layout
if [ -n "${given_kblayout}" -a -s "/mnt/${ostree_path}/usr/lib/kbd/keymaps/xkb/${given_kblayout}.map.gz" ]; then
	echo "Configuring keyboard layout ${given_kblayout}" 1>&2
	echo "KEYMAP=${given_kblayout}" > "/mnt/${ostree_path}/etc/vconsole.conf"
	chown root:root "/mnt/${ostree_path}/etc/vconsole.conf"
	chmod 644 "/mnt/${ostree_path}/etc/vconsole.conf"
else
	echo "Unspecified/invalid/unsupported keyboard layout '${given_kblayout}' - skipping" 1>&2
fi

# Set system hostname
echo "${given_hostname}" > "/mnt/${ostree_path}/etc/hostname"

# Configure NetworkManager
if [ "${given_persistnmconf}" = "true" ]; then
	# Copy the NetworkManager configuration previously detected/determined
	echo "Persisting NetworkManager configuration on the installed system" 1>&2
	for nm_conn_file in ${local_igncfg_cache}/system-connections/*.nmconnection ; do
		if [ -f "${nm_conn_file}" ]; then
			nm_conn_file_basename=$(basename "${nm_conn_file}")
			cp "${nm_conn_file}" "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nm_conn_file_basename}"
			chown root:root "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nm_conn_file_basename}"
			chmod 600 "/mnt/${ostree_path}/etc/NetworkManager/system-connections/${nm_conn_file_basename}"
		fi
	done
	for nm_conf_file in ${local_igncfg_cache}/system-connections/*.conf ; do
		if [ -f "${nm_conf_file}" ]; then
			nm_conf_file_basename=$(basename "${nm_conf_file}")
			cp "${nm_conf_file}" "/mnt/${ostree_path}/etc/NetworkManager/conf.d/${nm_conf_file_basename}"
			chown root:root "/mnt/${ostree_path}/etc/NetworkManager/conf.d/${nm_conf_file_basename}"
			chmod 644 "/mnt/${ostree_path}/etc/NetworkManager/conf.d/${nm_conf_file_basename}"
		fi
	done
fi

# Configure NTP client
if [ -n "${given_ntpservers}" ]; then
	sed -i -e '/^server\|pool/s/^/#/g' "/mnt/${ostree_path}/etc/chrony.conf"
	for ntpserver in $(echo "${given_ntpservers}" | sed -e 's/,/ /g') ; do
		sed -i -e "1s/^/server ${ntpserver} iburst\\n/" "/mnt/${ostree_path}/etc/chrony.conf"
	done
fi

# Configure embedded/layered packages, services and kernel arguments

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

