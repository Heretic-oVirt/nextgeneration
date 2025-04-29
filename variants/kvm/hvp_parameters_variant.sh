# Set default parameters
# Note: to influence node type selection logic add hvp_nodetype=XXX where XXX is one of standard*, installer

variant_type="KVM"
variant_version="2024120801"

# Packages and kernel arguments to be removed/replaced/added
default_removepkgs="nfs-utils-coreos"
default_replacepkgs="ncurses ncurses-base ncurses-libs"
default_addpkgs="tmux virt-install libvirt-daemon-config-network libvirt-daemon-kvm qemu-kvm guestfs-tools python3-libguestfs virt-top cockpit-system cockpit cockpit-ws cockpit-bridge cockpit-machines cockpit-networkmanager cockpit-ostree cockpit-podman cockpit-selinux mgmt libvirt-cim libvirt-client libvirt-client-qemu virt-backup ovn ovn-central ovn-host libvirt-lock-sanlock sanlock glusterfs glusterfs-fuse glusterfs-server glusterfs-coreutils glusterfs-cli glusterfs-geo-replication glusterfs-thin-arbiter glusterfs-client-xlators glusterfs-extra-xlators libvirt-daemon-driver-storage-gluster qemu-block-gluster glusterfs-fuse glusterfs-cloudsync-plugins drbd drbd-bash-completion drbd-selinux drbd-udev drbd-utils drbd-reactor resource-agents"
default_removekargs=""
default_replacekargs=""
default_addkargs=""
# Units to be masked/disabled/enabled
default_masksvcs=""
default_disablesvcs=""
default_enablesvcs="libvirtd.socket podman.socket podman.service cockpit.socket mgmt.service"
# Custom parameters
# Note: since these are evaluated after the usual embedded values, we take care of setting them only if undefined above
[ -z "${default_nodetype+x}" ] && default_nodetype="standard"

function pre_install_hook_custom_actions() {
	echo "pre_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} starting"
	# Determine node type
	given_nodetype=$(sed -n -e 's/^.*hvp_nodetype=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_nodetype}" ]; then
		given_nodetype="${default_nodetype}"
	fi
	# Note: network-related parameters demanded to post_install_hook_custom_actions to let the built-in network autoconfiguration happen first
	echo "pre_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} exiting"
}

function post_install_hook_custom_actions() {
	echo "post_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} starting"
	# Specialize installer/standard node
	case "${given_nodetype}" in
		installer)
			echo "Setting installer role for KVM node" 1>&2
			# TODO: assign the discovery IP on all the interfaces
			# TODO: configure and enable the mgmt provisioner service
			# TODO: copy the ISO and customize it to install further standard nodes using the mgmt provisioner
			;;
		*)
			# In any other case use standard as default role
			echo "Setting standard role for KVM node" 1>&2
			# TODO: Use the installer node IP as seed to join the mgmt cluster
			mgmt_seed="x.x.x.x"
			;;
	esac
	# Extract kernel commandline parameters

	# Define settings

	# Generate dynamic configuration files

	# Add repo file for HVP custom packages
	cat <<- EOF > "/mnt/${ostree_path}/etc/yum.repos.d/hvp.repo"
	[hvp]
	name=Heretic oVirt Project - Original packages
	baseurl=https://dangerous.ovirt.life/hvp-repos-development/fcos/\$releasever/hvp/
	gpgcheck=1
	enabled=1
	gpgkey=https://dangerous.ovirt.life/hvp-repos-development/RPM-GPG-KEY-hvp
	EOF
	chown root:root "/mnt/${ostree_path}/etc/yum.repos.d/hvp.repo"
	chmod 644 "/mnt/${ostree_path}/etc/yum.repos.d/hvp.repo"

	echo "post_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} exiting"
}

