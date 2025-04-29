# Set default parameters
# Note: to influence node type selection logic add hvp_nodetype=XXX where XXX is one of server, agent (default being server for up to three server nodes already autodetected and then agent beyond that)
# Note: to set cluster join token add hvp_jointoken=XXX where XXX is the token (automatically generated only if not specified for server node and no other server nodes found, otherwise should be manually copied from /var/lib/rancher/k3s/server/token on a running server node)
# Note: to set cluster join server add hvp_joinserver=https://XXX:6443 where XXX is the FQDN or IP of an already running server (automatically detected using first server node IP if not given)
# Note: to set loadbalanced K8s control-plane service IP add hvp_lbcontrolplaneip=X.Y.Z.V where X.Y.Z.V is the Kubernetes control-plane service IP address
# Note: to set loadbalanced services IP range add hvp_lbiprange=A.B.C.D-E.F.G.H or hvp_lbiprange=A.B.C.D/YY where A.B.C.D is the first and E.F.G.H is the last IP address available or A.B.C.D is the network IP address and YY is the prefix
# Note: to set loadbalanced DNS service IP add hvp_lbdnsip=L.M.N.O where L.M.N.O is the DNS service IP address (must be inside the hvp_lbiprange=A.B.C.D-E.F.G.H IP range)
# Note: to set K3s channel add hvp_k3schannel=XXX where XXX is one of stable*, testing, latest
# Note: to set K3s version add hvp_k3sversion=XXX where XXX is the version (the default being defined below)
# Note: to set Etcd CTL version add hvp_etcdctlversion=XXX where XXX is the version (the default being defined below)
# Note: to set Helm version add hvp_helmversion=XXX where XXX is the version (the default being defined below)
# Note: to set actions timeout add hvp_actions_timeout=XXX where XXX is the timeout for both kubectl and helm single deployments (the default being defined below)
# Note: to set System Update Controller version add hvp_sucversion=XXX where XXX is the version (the default being defined below)
# Note: to set KUbernetes REboot Daemon version add hvp_kuredversion=XXX where XXX is the version (the default being defined below)
# Note: to set Kube-VIP CP (Control Plane) version add hvp_kubevipcpversion=XXX where XXX is the version (the default being defined below)
# Note: to set Kube-VIP CC (Cloud Controller) version add hvp_kubevipccversion=XXX where XXX is the version (the default being defined below)
# Note: to set CertManager version add hvp_cmversion=XXX where XXX is the version (the default being defined below)
# Note: to set CertManager CTL version add hvp_cmctlversion=XXX where XXX is the version (the default being defined below)
# Note: to set CertManager Verifier version add hvp_cmvrfversion=XXX where XXX is the version (the default being defined below)
# Note: to set CoreDNS k8s_gateway version add hvp_cdnsk8sgwversion=XXX where XXX is the version (the default being defined below)
# Note: to set CoreDNS custom image version add hvp_cdnscustversion=XXX where XXX is the version (the default being defined below)
# Note: to set NGiNX version add hvp_nginxversion=XXX where XXX is the version (the default being defined below)
# Note: to set OpenEBS version add hvp_openebsversion=XXX where XXX is the version (the default being defined below)
# Note: to set Headlamp version add hvp_headlampversion=XXX where XXX is the version (the default being defined below)
# Note: to set Mirrors Controller version add hvp_mirrorsversion=XXX where XXX is the version (the default being defined below)

variant_type="K3s"
variant_version="2025040602"

# Packages and kernel arguments to be removed/replaced/added
default_removepkgs=""
default_replacepkgs=""
# TODO: switch to a proper yum/dnf repo as soon as possible in order to allow k3s-selinux to get automatically updated when updating Fedora CoreOS base layer
default_addpkgs="tmux yq https://github.com/k3s-io/k3s-selinux/releases/download/v1.6.latest.1/k3s-selinux-1.6-1.coreos.noarch.rpm"
default_removekargs=""
default_replacekargs=""
default_addkargs=""
# Units to be masked/disabled/enabled
default_masksvcs=""
default_disablesvcs="podman.socket firewalld.service nm-cloud-setup.service nm-cloud-setup.timer"
default_enablesvcs="install-k3s.service"
# Custom parameters
# Note: since these are evaluated after the standard embedded values, we take care of setting them only if undefined
[ -z "${default_server_configuration_templates+x}" ] && default_server_configuration_templates="customize-k8s.sh configure-k8s.service k3s-suc-plan.yaml k3s-upgrade.sh k3s-prepare.sh fcos-upgrade.sh need-reboot.sh fcos-suc-plan.yaml kured-values.yaml kubevipcp-values.yaml kubevipcc-configmap.yaml kubevipcc-values.yaml cert-manager-values.yaml cert-manager-cachain.yaml customcoredns-kubenodes-rbac.yaml customcoredns-values.yaml nginx-values.yaml openebs-values.yaml openebs-localpv-config.yaml openebs-mayastor-config-1-node.yaml openebs-mayastor-config-3-nodes.yaml headlamp-values.yaml"
[ -z "${default_agent_configuration_templates+x}" ] && default_agent_configuration_templates="need-reboot.sh"
[ -z "${default_nodetype+x}" ] && default_nodetype=""
[ -z "${default_jointoken+x}" ] && default_jointoken=""
[ -z "${default_joinserver+x}" ] && default_joinserver=""
[ -z "${default_lbcontrolplaneip+x}" ] && default_lbcontrolplaneip=""
[ -z "${default_lbiprange+x}" ] && default_lbiprange=""
[ -z "${default_lbdnsip+x}" ] && default_lbdnsip=""
# K3s channels and versions can be verified at https://update.k3s.io/v1-release/channels
[ -z "${default_k3schannel+x}" ] && default_k3schannel="stable"
[ -z "${default_k3sversion+x}" ] && default_k3sversion="v1.30.6+k3s1"
# K3s built-in Etcd version can be deduced from release notes at https://github.com/k3s-io/k3s/releases and downloaded from https://github.com/etcd-io/etcd/releases
[ -z "${default_etcdctlversion+x}" ] && default_etcdctlversion="v3.5.17"
# Helm version can be verified at https://github.com/helm/helm/releases
[ -z "${default_helmversion+x}" ] && default_helmversion="3.16.3"
[ -z "${default_actions_timeout+x}" ] && default_actions_timeout="10m"
# System Update Controller version can be verified at https://github.com/rancher/system-upgrade-controller/releases
[ -z "${default_sucversion+x}" ] && default_sucversion="v0.14.2"
# KUbernetes REboot Daemon version can be verified at https://github.com/kubereboot/charts/tree/main/charts/kured
[ -z "${default_kuredversion+x}" ] && default_kuredversion="5.5.2"
# Kube-VIP versions can be verified at https://github.com/kube-vip/helm-charts/tree/main/charts
[ -z "${default_kubevipcpversion+x}" ] && default_kubevipcpversion="0.6.4"
[ -z "${default_kubevipccversion+x}" ] && default_kubevipccversion="0.2.5"
# CertManager version can be verified at https://artifacthub.io/packages/helm/cert-manager/cert-manager
[ -z "${default_cmversion+x}" ] && default_cmversion="1.16.2"
# CertManager CTL version can be verified at https://github.com/cert-manager/cmctl/releases
[ -z "${default_cmctlversion+x}" ] && default_cmctlversion="2.1.1"
# CertManager Verifier version can be verified at https://github.com/alenkacz/cert-manager-verifier/releases
[ -z "${default_cmvrfversion+x}" ] && default_cmvrfversion="0.3.0"
# CoreDNS k8s_gateway version can be verified at https://github.com/ori-edge/k8s_gateway/tree/master/charts
[ -z "${default_cdnsk8sgwversion+x}" ] && default_cdnsk8sgwversion="2.4.0"
# CoreDNS custom image version can be verified at https://github.com/wittenbude/coredns/tags
[ -z "${default_cdnscustversion+x}" ] && default_cdnscustversion="v0.1.9"
# NGiNX version can be verified at https://github.com/kubernetes/ingress-nginx/releases
[ -z "${default_nginxversion+x}" ] && default_nginxversion="4.11.3"
# OpenEBS version can be verified at https://github.com/openebs/openebs/blob/main/charts/Chart.yaml
[ -z "${default_openebsversion+x}" ] && default_openebsversion="4.1.1"
# Headlamp version can be verified at https://github.com/headlamp-k8s/headlamp/blob/main/charts/headlamp/Chart.yaml
[ -z "${default_headlampversion+x}" ] && default_headlampversion="0.26.0"
# Mirrors Controller version can be verified at https://github.com/ktsstudio/mirrors/tags
[ -z "${default_mirrorsversion+x}" ] && default_mirrorsversion="0.1.9"

function pre_install_hook_custom_actions() {
	echo "pre_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} starting"
	# Note: network-related parameters management demanded to post_install_hook_custom_actions to let the built-in network autoconfiguration happen first
	
	# Retrieve variant-related additional files
	if [ -z "${ign_dev}" ]; then
		echo "Unable to extract Ignition source - skipping ${variant_type} configuration files retrieval" 1>&2
	else
		if [ -n "${default_server_configuration_templates}" ]; then
			server_configuration_templates="${default_server_configuration_templates}"
		else
			server_configuration_templates=""
		fi
		if [ -n "${default_agent_configuration_templates}" ]; then
			agent_configuration_templates="${default_agent_configuration_templates}"
		else
			agent_configuration_templates=""
		fi
		mkdir -p ${local_igncfg_cache}/${variant_type}
		# Note: since the node type is still unknown, server configuration templates will be initially retrieved also on agent nodes
		for config_tpl in ${server_configuration_templates} ${agent_configuration_templates}; do
			if [ "${ign_fstype}" = "url" ]; then
				# Note: network-based configuration template retrieval autodetected
				echo "Attempting network retrieval of ${ign_dev}/${config_tpl}" 1>&2
				curl -o "${local_igncfg_cache}/${variant_type}/${config_tpl}" -C - "${ign_dev}/${config_tpl}" || true
			else
				# Note: filesystem-based configuration configuration template retrieval autodetected
				echo "Attempting filesystem retrieval of ${ign_dev}/${config_tpl}" 1>&2
				cp -f "${ign_dev}/${config_tpl}" "${local_igncfg_cache}/${variant_type}/${config_tpl}" || true
			fi
		done
	fi
	
	echo "pre_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} exiting"
}

function post_install_hook_custom_actions() {
	echo "post_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} starting"

	# Determine the loadbalanced K8s control-plane service IP address
	# Note: if not explicitly given then it must be detected later at runtime (when free service IPs can be actually autodetected)
	given_lbcontrolplaneip=$(sed -n -e 's/^.*hvp_lbcontrolplaneip=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_lbcontrolplaneip}" ]; then
		given_lbcontrolplaneip="${default_lbcontrolplaneip}"
	fi
	if [ -n "${given_lbcontrolplaneip}" ]; then
		# Check IP validity
		if ! ipcalc -s -c "${given_lbcontrolplaneip}" ; then
			given_lbcontrolplaneip=""
		# Check whether it is coherent with assigned IP address and network
		elif [ "$(ipcalc -s --no-decorate -n "${given_lbcontrolplaneip}/${network_prefix}")" != "$(ipcalc -s --no-decorate -n "${assigned_ipaddr}/${network_prefix}")" ]; then
			given_lbcontrolplaneip=""
		# Check whether the specified IP is currently free
		else
			res=0
			ping -c 3 -w 8 -i 2 "${given_lbcontrolplaneip}" > /dev/null 2>&1 || res=1
			if [ ${res} -eq 1 ]; then
				# Forcibly unassign a currently used IP
				given_lbcontrolplaneip=""
			fi
		fi
	fi

	# Determine the loadbalanced services IP range
	# Note: if not explicitly given then it must be detected later at runtime (when free service IPs can be actually autodetected)
	given_lbiprange=$(sed -n -e 's/^.*hvp_lbiprange=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_lbiprange}" ]; then
		given_lbiprange="${default_lbiprange}"
	fi
	if [ -n "${given_lbiprange}" ]; then
		# TODO: support also a CIDR-type syntax
		given_lowip=$(echo "${given_lbiprange}" | sed -e 's/^\([^-]*\)-.*$/\1/')
		given_highip=$(echo "${given_lbiprange}" | sed -e 's/^[^-]*-\(.*\)$/\1/')
		# Check low IP validity
		if ! ipcalc -s -c "${given_lowip}" ; then
			given_lowip=""
		# Check whether it is coherent with assigned IP address and network
		elif [ "$(ipcalc -s --no-decorate -n "${given_lowip}/${network_prefix}")" != "$(ipcalc -s --no-decorate -n "${assigned_ipaddr}/${network_prefix}")" ]; then
			given_lowip=""
		fi
		# Check high IP validity
		if ! ipcalc -s -c "${given_highip}" ; then
			given_highip=""
		# Check whether it is coherent with assigned IP address and network
		elif [ "$(ipcalc -s --no-decorate -n "${given_highip}/${network_prefix}")" != "$(ipcalc -s --no-decorate -n "${assigned_ipaddr}/${network_prefix}")" ]; then
			given_highip=""
		fi
		# Force range undefined if either low or high IP is invalid
		if [ -z "${given_lowip}" -o -z "${given_highip}" ]; then
			given_lbiprange=""
		fi
	fi

	# Determine the loadbalanced DNS service IP address
	# Note: if not explicitly given then it must be detected later at runtime (when free service IPs can be actually autodetected)
	given_lbdnsip=$(sed -n -e 's/^.*hvp_lbdnsip=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_lbdnsip}" ]; then
		given_lbdnsip="${default_lbdnsip}"
	fi
	if [ -n "${given_lbdnsip}" ]; then
		# Check IP validity
		if ! ipcalc -s -c "${given_lbdnsip}" ; then
			given_lbdnsip=""
		# Check whether it is coherent with assigned IP address and network
		elif [ "$(ipcalc -s --no-decorate -n "${given_lbdnsip}/${network_prefix}")" != "$(ipcalc -s --no-decorate -n "${assigned_ipaddr}/${network_prefix}")" ]; then
			given_lbdnsip=""
		# Check whether it is within the assigned IP service range
		elif [ -n "${given_lbiprange}" ]; then
			distance_low_high=$(ipdiff ${given_highip} ${given_lowip})
			distance_to_low=$(ipdiff ${given_lbdnsip} ${given_lowip})
			distance_to_high=$(ipdiff ${given_lbdnsip} ${given_highip})
			if [ ${distance_low_high} -ne $((${distance_to_low} + ${distance_to_high})) ]; then
				given_lbdnsip=""
			fi
		fi
	fi

	# Determine cluster joining token
	given_jointoken=$(sed -n -e 's/^.*hvp_jointoken=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_jointoken}" ]; then
		if [ -n "${default_jointoken}" ]; then
			given_jointoken="${default_jointoken}"
		fi
	fi
	
	# Determine cluster joining server
	given_joinserver=$(sed -n -e 's/^.*hvp_joinserver=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_joinserver}" ]; then
		if [ -n "${default_joinserver}" ]; then
			given_joinserver="${default_joinserver}"
		fi
	fi
	# Check the given join server
	if [ -n "${given_joinserver}" ]; then
		if [ -z "$(curl -k -s ${given_joinserver}/v1-k3s/config | jq .kind)" ]; then
			echo "Skipping invalid join server ${given_joinserver}" 1>&2
			given_joinserver=""
		fi
	fi
	# Use network configuration parameters to try to identify all already up-and-running ${variant_type} server nodes
	echo "Autodetecting server nodes" 1>&2
	server_nodes_num=0
	# Cycle on all possible IPs to find the first one held by a ${variant_type} control-plane node
	for index in $(seq 0 $((addresses_to_try - 1))) ; do
		tentative_joinserver_ipaddr=$(ipmat ${first_address} ${index} +)
		if [ -n "$(curl -k -s https://${tentative_joinserver_ipaddr}:6443/v1-k3s/config | jq .kind)" ]; then
			echo "Found valid join server ${tentative_joinserver_ipaddr}" 1>&2
			server_nodes_num=$((server_nodes_num + 1))
			# If no join server was given, the first server found is automatically selected
			if [ -z "${given_joinserver}" ]; then
				given_joinserver="https://${tentative_joinserver_ipaddr}:6443"
			fi
		else
			continue
		fi
	done

	# Specialize server/agent node
	given_nodetype=$(sed -n -e 's/^.*hvp_nodetype=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_nodetype}" ]; then
		if [ -n "${default_nodetype}" ]; then
			given_nodetype="${default_nodetype}"
		else
			# Note: if no default node type specified then automatically create only up to 3 server nodes
			if [ ${server_nodes_num} -lt 3 ]; then
				given_nodetype="server"
			else
				given_nodetype="agent"
			fi
		fi
	fi
	case "${given_nodetype}" in
		server)
			echo "Setting server role for ${variant_type} node" 1>&2
			k3s_service="k3s"
			k3s_options="server --selinux --secrets-encryption --embedded-registry --flannel-backend=host-gw --disable servicelb --disable traefik"
			# Disable local-storage provider if OpenEBS LocalPV is going to be installed
			if [ -n "${localst_actual_vg_name}" ]; then
				k3s_options="${k3s_options} --disable local-storage"
			fi
			# Add TLS SAN option for using a VIP for the K8s control-plane
			k3s_options="${k3s_options} --tls-san k8sapi.${given_domainname}"
			;;
		*)
			# In any other case use agent as default type
			echo "Setting agent role for ${variant_type} node" 1>&2
			given_nodetype="agent"
			k3s_service="k3s-agent"
			k3s_options="agent --selinux"
			;;
	esac

	# Determine join server
	if [ -z "${given_joinserver}" ]; then
		if [ "${given_nodetype}" = "agent" ]; then
			# Note: generating a forcibly invalid join server URL if not given and this node is an agent node
			given_joinserver="set.actual.join.server.fqdn.and.restart.k3s.service"
			echo "No valid join server found - manual intervention will be needed" 1>&2
			if [ -z "${default_jointoken}" ]; then
				# Note: generating a forcibly invalid token if not given and this node is an agent node 
				given_jointoken="set_actual_token_value_and_restart_k3s_service"
				echo "No valid join token found - manual intervention will be needed" 1>&2
			fi
		else
			if [ -z "${given_jointoken}" ]; then
				# Note: generating a random token if not given and this node is the only server node found
				given_jointoken=$(openssl rand -hex 16)
			fi
			k3s_options="${k3s_options} --cluster-init"
		fi
	else
		if [ -z "${given_jointoken}" ]; then
			# Note: generating a random token if not given and this node is an additional server node
			given_jointoken="set_actual_token_value_and_restart_k3s_service"
		fi
	fi
	if [ -n "${given_joinserver}" ]; then
		k3s_options="${k3s_options} --server=${given_joinserver}"
	fi
	k3s_options="${k3s_options} --token=${given_jointoken}"
	
	# Determine K3s channel
	given_k3schannel=$(sed -n -e 's/^.*hvp_k3schannel=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_k3schannel}" ]; then
		given_k3schannel="${default_k3schannel}"
	fi
	
	# Determine K3s version
	given_k3sversion=$(sed -n -e 's/^.*hvp_k3sversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_k3sversion}" ]; then
		given_k3sversion="${default_k3sversion}"
	fi
	
	# Determine Etcdctl version
	given_etcdctlversion=$(sed -n -e 's/^.*hvp_etcdctlversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_etcdctlversion}" ]; then
		given_etcdctlversion="${default_etcdctlversion}"
	fi
	
	# Determine Helm version
	given_helmversion=$(sed -n -e 's/^.*hvp_helmversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_helmversion}" ]; then
		given_helmversion="${default_helmversion}"
	fi
	
	# Determine actions timeout
	given_actions_timeout=$(sed -n -e 's/^.*hvp_actions_timeout=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_actions_timeout}" ]; then
		given_actions_timeout="${default_actions_timeout}"
	fi
	
	# Determine System Update Controller version
	given_sucversion=$(sed -n -e 's/^.*hvp_sucversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_sucversion}" ]; then
		given_sucversion="${default_sucversion}"
	fi
	
	# Determine KUbernetes REboot Daemon version
	given_kuredversion=$(sed -n -e 's/^.*hvp_kuredversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_kuredversion}" ]; then
		given_kuredversion="${default_kuredversion}"
	fi
	
	# Determine Kube-VIP CP version
	given_kubevipcpversion=$(sed -n -e 's/^.*hvp_kubevipcpversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_kubevipcpversion}" ]; then
		given_kubevipcpversion="${default_kubevipcpversion}"
	fi
	
	# Determine Kube-VIP CC version
	given_kubevipccversion=$(sed -n -e 's/^.*hvp_kubevipccversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_kubevipccversion}" ]; then
		given_kubevipccversion="${default_kubevipccversion}"
	fi
	
	# Determine CertManager version
	given_cmversion=$(sed -n -e 's/^.*hvp_cmversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_cmversion}" ]; then
		given_cmversion="${default_cmversion}"
	fi
	
	# Determine CertManager CTL version
	given_cmctlversion=$(sed -n -e 's/^.*hvp_cmctlversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_cmctlversion}" ]; then
		given_cmctlversion="${default_cmctlversion}"
	fi
	
	# Determine CertManager Verifier version
	given_cmvrfversion=$(sed -n -e 's/^.*hvp_cmvrfversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_cmvrfversion}" ]; then
		given_cmvrfversion="${default_cmvrfversion}"
	fi
	
	# Determine CoreDNS k8s_gateway version
	given_cdnsk8sgwversion=$(sed -n -e 's/^.*hvp_cdnsk8sgwversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_cdnsk8sgwversion}" ]; then
		given_cdnsk8sgwversion="${default_cdnsk8sgwversion}"
	fi
	
	# Determine CoreDNS custom image version
	given_cdnscustversion=$(sed -n -e 's/^.*hvp_cdnscustversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_cdnscustversion}" ]; then
		given_cdnscustversion="${default_cdnscustversion}"
	fi
	
	# Determine NGiNX version
	given_nginxversion=$(sed -n -e 's/^.*hvp_nginxversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_nginxversion}" ]; then
		given_nginxversion="${default_nginxversion}"
	fi
	
	# Determine OpenEBS version
	given_openebsversion=$(sed -n -e 's/^.*hvp_openebsversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_openebsversion}" ]; then
		given_openebsversion="${default_openebsversion}"
	fi
	
	# Determine Headlamp version
	given_headlampversion=$(sed -n -e 's/^.*hvp_headlampversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_headlampversion}" ]; then
		given_headlampversion="${default_headlampversion}"
	fi
	
	# Determine Mirrors Controller version
	given_mirrorsversion=$(sed -n -e 's/^.*hvp_mirrorsversion=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_mirrorsversion}" ]; then
		given_mirrorsversion="${default_mirrorsversion}"
	fi

	# TODO: Check parameters coherence (Keycloak needs PostgreSQL etc)
	
	# Generate dynamic configuration files
	
	# Add NetworkManager configuration snippet to avoid interfering with CNI-created interfaces
	# Note: post_install_hook_custom_actions runs before retrieved/detected NetworkManager configuration is (optionally) persisted into installed system
	if [ "${given_persistnmconf}" = "true" ]; then
		existing_nmconf_fragment=$(grep -H 'unmanaged-devices=' ${local_igncfg_cache}/system-connections/*.conf 2>/dev/null | sed -e 's/^\([^:]*\):.*$/\1/')
		if [ -z "${existing_nmconf_fragment}" ]; then
			cat <<- EOF > "${local_igncfg_cache}/system-connections/99-unmanaged-devices.conf"
			[keyfile]
			unmanaged-devices=interface-name:cali*;interface-name:flannel*
			EOF
		else
			sed -i -e '/^unmanaged-devices=/s/$/;interface-name:cali*;interface-name:flannel*/' "${existing_nmconf_fragment}"
		fi
	else
		# Make this setting persist even when not persisting retrieved/detected NetworkManager configuration
		cat <<- EOF > "/mnt/${ostree_path}/etc/NetworkManager/conf.d/99-unmanaged-devices.conf"
		[keyfile]
		unmanaged-devices=interface-name:cali*;interface-name:flannel*
		EOF
		chown root:root "/mnt/${ostree_path}/etc/NetworkManager/conf.d/99-unmanaged-devices.conf"
		chmod 644 "/mnt/${ostree_path}/etc/NetworkManager/conf.d/99-unmanaged-devices.conf"
	fi
	
	# Add LVM Thin Pool module preloading for OpenEBS LocalPV-LVM
	if [ -n "${localst_actual_vg_name}" ]; then
		cat <<- EOF > "/mnt/${ostree_path}/etc/modules-load.d/openebs-localpv-lvm.conf"
		dm_thin_pool
		EOF
		chown root:root "/mnt/${ostree_path}/etc/modules-load.d/openebs-localpv-lvm.conf"
		chmod 644 "/mnt/${ostree_path}/etc/modules-load.d/openebs-localpv-lvm.conf"
	fi
	
	# Add hugepages configuration for OpenEBS Mayastor
	if [ -n "${replicatedst_actual_disk_name}" ]; then
		cat <<- EOF > "/mnt/${ostree_path}/etc/sysctl.d/100-hugepages.conf"
		vm.nr_hugepages = 1024
		EOF
		chown root:root "/mnt/${ostree_path}/etc/sysctl.d/100-hugepages.conf"
		chmod 644 "/mnt/${ostree_path}/etc/sysctl.d/100-hugepages.conf"
	fi
	
	# Add configuration file required by install-k3s.service
	cat <<- EOF > "/mnt/${ostree_path}/etc/sysconfig/k3s-settings"
	# Define ${variant_type} installation parameters
	# Note: newer Helm versions complain loudly if set to 644
	K3S_KUBECONFIG_MODE="600"
	INSTALL_K3S_CHANNEL="${given_k3schannel}"
	INSTALL_K3S_VERSION="${given_k3sversion}"
	INSTALL_K3S_SELINUX_WARN="true"
	INSTALL_K3S_SKIP_SELINUX_RPM="true"
	# Adding further dynamically deduced ${variant_type} parameters
	INSTALL_K3S_EXEC="${k3s_options}"
	# Note: it seems that the k3s executable gets incorrectly labeled - working around by inhibiting autostart and manually invoking restorecon
	INSTALL_K3S_SKIP_ENABLE="true"
	# Note: etcdctl is not provided by ${variant_type} - manually installing (useful for checks like: etcdctl endpoint status --cluster -w table)
	# TODO: should try to automatically deduce the Etcd version embedded in ${variant_type} using: curl -s -L --cacert /var/lib/rancher/k3s/server/tls/etcd/server-ca.crt --cert /var/lib/rancher/k3s/server/tls/etcd/server-client.crt --key /var/lib/rancher/k3s/server/tls/etcd/server-client.key https://127.0.0.1:2382/version | jq .etcdserver
	INSTALL_ETCDCTL_VERSION="${given_etcdctlversion}"
	INSTALL_HELM_VERSION="${given_helmversion}"
	INSTALL_CMCTL_VERSION="${given_cmctlversion}"
	INSTALL_CERTMANAGER_VERIFIER_VERSION="${given_cmvrfversion}"
	EOF
	chown root:root "/mnt/${ostree_path}/etc/sysconfig/k3s-settings"
	chmod 644 "/mnt/${ostree_path}/etc/sysconfig/k3s-settings"
	
	# Add container registries configuration to enable the built-in local mirroring service
	mkdir -p "/mnt/${ostree_path}/etc/rancher/k3s"
	cat <<- EOF > "/mnt/${ostree_path}/etc/rancher/k3s/registries.yaml"
	mirrors:
	  "*":
	EOF
	chown root:root "/mnt/${ostree_path}/etc/rancher/k3s/registries.yaml"
	chmod 644 "/mnt/${ostree_path}/etc/rancher/k3s/registries.yaml"

	# Add specialized installation unit
	cat <<- EOF > "/mnt/${ostree_path}/etc/systemd/system/install-k3s.service"
	[Unit]
	Description=Install ${variant_type}
	# Run after required RPM dependencies and kernel settings have been installed and layered services have been started
	# Note: no need to force after nor requires dependencies since we will be enabled and started properly by the setup-layered-services.service
	After=network-online.target
	Requires=network-online.target
	# Do not execute anymore if it was already installed
	ConditionPathExists=!/var/lib/%N.stamp
	
	[Service]
	Type=oneshot
	TimeoutStartSec=infinity
	EnvironmentFile=/etc/sysconfig/k3s-settings
	# Note: stopping any running ${variant_type} in case this is an upgrade (makes sure to start the new version afterwards)
	ExecStartPre=/usr/bin/bash -c '/usr/bin/systemctl stop ${k3s_service}.service || true'
	# Add local system images for an air-gap-like environment
	ExecStart=/usr/bin/mkdir -p "/var/lib/rancher/k3s/agent/images/"
	ExecStart=/usr/bin/rm -f "/var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar.zst"
	ExecStart=/usr/bin/curl -L -o "/var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar.zst" "https://github.com/k3s-io/k3s/releases/download/\${INSTALL_K3S_VERSION}/k3s-airgap-images-amd64.tar.zst"
	# Perform basic installation/upgrade of ${variant_type}
	ExecStart=/usr/bin/bash -c '/usr/bin/curl -sfL https://get.k3s.io | /usr/bin/sh -'
	ExecStart=/usr/sbin/restorecon -Rv /usr/local/bin
	# Note: ${variant_type} creates some needed dirs/files only on first execution
	ExecStart=/usr/bin/systemctl --now enable ${k3s_service}.service
	# Note: kubectl link does not get automatically created if already provided by a builtin package
	ExecStart=/usr/bin/ln -sf k3s /usr/local/bin/kubectl
	ExecStart=/usr/bin/bash -c '/usr/local/bin/kubectl completion bash > /etc/bash_completion.d/kubectl'
	# Note: crictl link does not get automatically created if already provided by a builtin package
	ExecStart=/usr/bin/ln -sf k3s /usr/local/bin/crictl
	ExecStart=/usr/bin/bash -c '/usr/local/bin/crictl completion bash > /etc/bash_completion.d/crictl'
	# Note: ctr link does not get automatically created if already provided by a builtin package
	ExecStart=/usr/bin/ln -sf k3s /usr/local/bin/ctr
	# Note: no bash completion support seems present in ctr
	#ExecStart=/usr/bin/bash -c '/usr/local/bin/ctr completion bash > /etc/bash_completion.d/ctr'
	# TODO: on agent nodes the kubeconfig file is not available - find a workaround
	ExecStart=/usr/bin/bash -c '/usr/bin/echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" > /etc/profile.d/k3s.sh'
	ExecStart=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/etcd-io/etcd/releases/download/\${INSTALL_ETCDCTL_VERSION}/etcd-\${INSTALL_ETCDCTL_VERSION}-linux-amd64.tar.gz | /usr/bin/tar xOzf - etcd-\${INSTALL_ETCDCTL_VERSION}-linux-amd64/etcdctl > /usr/local/bin/etcdctl'
	ExecStart=/usr/bin/chmod a+rx /usr/local/bin/etcdctl
	ExecStart=/usr/bin/bash -c '/usr/bin/echo "export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379 ETCDCTL_CACERT=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt ETCDCTL_CERT=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt ETCDCTL_KEY=/var/lib/rancher/k3s/server/tls/etcd/server-client.key ETCDCTL_API=3" >> /etc/profile.d/k3s.sh'
	ExecStart=/usr/bin/bash -c '/usr/bin/curl -sfL https://get.helm.sh/helm-v\${INSTALL_HELM_VERSION}-linux-amd64.tar.gz | /usr/bin/tar xOzf - linux-amd64/helm > /usr/local/bin/helm'
	ExecStart=/usr/bin/chmod a+rx /usr/local/bin/helm
	ExecStart=/usr/bin/bash -c '/usr/local/bin/helm completion bash > /etc/bash_completion.d/helm'
	ExecStart=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/cert-manager/cmctl/releases/download/v\${INSTALL_CMCTL_VERSION}/cmctl_linux_amd64 > /usr/local/bin/cmctl'
	ExecStart=/usr/bin/chmod a+rx /usr/local/bin/cmctl
	ExecStart=/usr/bin/ln -sf cmctl /usr/local/bin/kubectl_cert-manager 
	ExecStart=/usr/bin/bash -c '/usr/local/bin/cmctl completion bash > /etc/bash_completion.d/cmctl'
	ExecStart=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/alenkacz/cert-manager-verifier/releases/download/v\${INSTALL_CERTMANAGER_VERIFIER_VERSION}/cert-manager-verifier_\${INSTALL_CERTMANAGER_VERIFIER_VERSION}_Linux_x86_64.tar.gz | /usr/bin/tar xOzf - cm-verifier > /usr/local/bin/cm-verifier'
	ExecStart=/usr/bin/chmod a+rx /usr/local/bin/cm-verifier
	# Note: confirming that execution was successfully completed - running again will require manual removing
	ExecStartPost=/usr/bin/touch /var/lib/%N.stamp
	
	[Install]
	WantedBy=multi-user.target
	EOF
	chown root:root "/mnt/${ostree_path}/etc/systemd/system/install-k3s.service"
	chmod 644 "/mnt/${ostree_path}/etc/systemd/system/install-k3s.service"

	# Create the specific configuration files and the configuration service only on a server node
	if [ "${given_nodetype}" = "server" ]; then
		# Automatically detect the currently running Fedora CoreOS version
		# Note: assuming that the Live installation environment has the same version as the installed one
		# TODO: try to extract the actual installed version - maybe playing with the --sysroot option
		current_fcos_version=$(rpm-ostree status --booted --json | jq -r '.deployments[] | select(.booted==true).version')
		
		# Add configuration file required by configure-k8s.service
		# Note: the specialized configuration unit is included in the externally provided files in order to allow dynamically changing/extending the logic
		cat <<- EOF > "/mnt/${ostree_path}/etc/sysconfig/k8s-addons"
		# Define K8s addon configuration parameters
		# Note: Helm tries to find HOME for storing cache/config - setting here since systemd removes it from env
		HOME="/root"
		# Note: Helm cannot find cluster connection config from environment variable - setting here since systemd removes it from env
		KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
		ACTIONS_TIMEOUT="${given_actions_timeout}"
		INSTALL_SUC_VERSION="${given_sucversion}"
		INSTALL_KURED_VERSION="${given_kuredversion}"
		# Note: the Fedora CoreOS version is cited in this file only because it is managed by SUC/kured based strategies
		# Note: the Fedora CoreOS current version is automatically detected and updated below - do not change it manually
		SUC_CURRENT_FCOS_VERSION="${current_fcos_version}"
		# Note: fill in the desired Fedora CoreOS desired version below and rerun the configure-k8s service - pay attention to barrier releases when selecting the target version
		SUC_TARGET_FCOS_VERSION="${current_fcos_version}"
		INSTALL_KUBEVIPCP_VERSION="${given_kubevipcpversion}"
		INSTALL_KUBEVIPCC_VERSION="${given_kubevipccversion}"
		INSTALL_CERTMANAGER_VERSION="${given_cmversion}"
		INSTALL_COREDNSK8SGATEWAY_VERSION="${given_cdnsk8sgwversion}"
		INSTALL_COREDNSCUSTOM_VERSION="${given_cdnscustversion}"
		INSTALL_NGINX_VERSION="${given_nginxversion}"
		INSTALL_OPENEBS_VERSION="${given_openebsversion}"
		INSTALL_OPENEBSLOCAL_VG="${localst_actual_vg_name}"
		INSTALL_OPENEBSREPLICATED_DISK="${replicatedst_actual_disk_name}"
		INSTALL_HEADLAMP_VERSION="${given_headlampversion}"
		INSTALL_MIRRORS_VERSION="${given_mirrorsversion}"
		EOF
		chown root:root "/mnt/${ostree_path}/etc/sysconfig/k8s-addons"
		chmod 644 "/mnt/${ostree_path}/etc/sysconfig/k8s-addons"
		
		# Add configuration file required by customize-k8s.service
		# TODO: rewrite to use dynamically generated variable names based on the __HVP_XXX_HVP__ strings dynamically found in the files under templates_dir
		cat <<- EOF > "/mnt/${ostree_path}/etc/sysconfig/k8s-environment"
		# Define K8s customization parameters
		GIVEN_TIMEZONE="${given_timezone}"
		MAIN_INTERFACE="${main_interface}"
		GIVEN_DOMAINNAME="${given_domainname}"
		GIVEN_NAMESERVERS="${given_nameservers}"
		LBCONTROLPLANEIP="${given_lbcontrolplaneip}"
		LBIPRANGE="${given_lbiprange}"
		LBDNSIP="${given_lbdnsip}"
		LOCALST_VGNAME="${localst_actual_vg_name}"
		REPLICATEDST_DISKNAME="${replicatedst_actual_disk_name}"
		GATEWAY_ADDRESS="${gateway_address}"
		NETWORK_PREFIX="${network_prefix}"
		FIRST_ADDRESS="${first_address}"
		ADDRESSES_TO_TRY="${addresses_to_try}"
		EOF
		chown root:root "/mnt/${ostree_path}/etc/sysconfig/k8s-environment"
		chmod 644 "/mnt/${ostree_path}/etc/sysconfig/k8s-environment"
		
		# Add customization unit for the configuration files above needed by the specialized configuration unit further below
		# Note: the customization script is included in the externally provided files in order to allow dynamically changing/extending the logic
		# Note: immediately after installation the /var/usrlocal dir (pointed to by the symlink /usr/local) is not present yet
		cat <<- EOF > "/mnt/${ostree_path}/etc/systemd/system/customize-k8s.service"
		[Unit]
		Description=Customize configuration files of further required components for K8s
		# Run before installing further required components
		After=network-online.target install-k3s.service
		Requires=network-online.target install-k3s.service
		Before=configure-k8s.service
		# Execute only when manually allowed
		# Note: This should be manually allowed only after all desired nodes have joined the cluster
		ConditionPathExists=/etc/sysconfig/configure-k8s.allowed
		# Do not execute anymore if it was already installed
		ConditionPathExists=!/var/lib/%N.stamp
		
		[Service]
		Type=oneshot
		TimeoutStartSec=infinity
		EnvironmentFile=/etc/sysconfig/k8s-environment
		EnvironmentFile=/etc/sysconfig/k8s-addons
		ExecStart=/etc/rancher/k3s/hvp/customize-k8s.sh /etc/rancher/k3s/hvp
		# Note: confirming that execution was successfully completed - running again will require manual removing but is currently unsupported
		ExecStartPost=/usr/bin/touch /var/lib/%N.stamp
		
		[Install]
		WantedBy=multi-user.target configure-k8s.service
		EOF
		chown root:root "/mnt/${ostree_path}/etc/systemd/system/customize-k8s.service"
		chmod 644 "/mnt/${ostree_path}/etc/systemd/system/customize-k8s.service"
	
		# Persist previously retrieved variant-related additional server files inside the installed system
		# Note: immediately after installation the /var/usrlocal dir (pointed to by the symlink /usr/local) is not present yet
		echo "Persisting ${variant_type} server configuration on the installed system" 1>&2
		for conf_tpl in ${server_configuration_templates}; do
			conf_file="${local_igncfg_cache}/${variant_type}/${conf_tpl}"
			if [ -f "${conf_file}" ]; then
				if file "${conf_file}" | grep -q 'executable' ; then
					conf_file_subdir="/etc/rancher/k3s/hvp"
					conf_file_perms="700"
				elif echo "${conf_file}" | grep -Eq '[.](service|target|slice|timer|mount|automount|socket)$'; then
					conf_file_subdir="/etc/systemd/system"
					conf_file_perms="644"
				else
					conf_file_subdir="/etc/rancher/k3s/hvp/tpl"
					conf_file_perms="600"
				fi
				mkdir -p "/mnt/${ostree_path}${conf_file_subdir}"
				cp "${conf_file}" "/mnt/${ostree_path}${conf_file_subdir}/${conf_tpl}"
				chown root:root "/mnt/${ostree_path}${conf_file_subdir}/${conf_tpl}"
				chmod ${conf_file_perms} "/mnt/${ostree_path}${conf_file_subdir}/${conf_tpl}"
			fi
		done

	else
		# Persist previously retrieved variant-related additional agent files inside the installed system
		# Note: immediately after installation the /var/usrlocal dir (pointed to by the symlink /usr/local) is not present yet
		echo "Persisting ${variant_type} agent configuration on the installed system" 1>&2
		for conf_tpl in ${agent_configuration_templates}; do
			conf_file="${local_igncfg_cache}/${variant_type}/${conf_tpl}"
			if [ -f "${conf_file}" ]; then
				if file "${conf_file}" | grep -q 'executable' ; then
					conf_file_subdir="/etc/rancher/k3s/hvp"
					conf_file_perms="700"
				elif echo "${conf_file}" | grep -Eq '[.](service|target|slice|timer|mount|automount|socket)$'; then
					conf_file_subdir="/etc/systemd/system"
					conf_file_perms="644"
				else
					conf_file_subdir="/etc/rancher/k3s/hvp/tpl"
					conf_file_perms="600"
				fi
				mkdir -p "/mnt/${ostree_path}${conf_file_subdir}"
				cp "${conf_file}" "/mnt/${ostree_path}${conf_file_subdir}/${conf_tpl}"
				chown root:root "/mnt/${ostree_path}${conf_file_subdir}/${conf_tpl}"
				chmod ${conf_file_perms} "/mnt/${ostree_path}${conf_file_subdir}/${conf_tpl}"
			fi
		done
	fi
	echo "post_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} exiting"
}

