# Set default parameters
# Note: to influence node type selection logic add hvp_nodetype=XXX where XXX is one of server*, agent
# Note: to influence node id selection logic add hvp_nodeid=N where N is one of 0*, 1, 2, 3, etc.
# Note: to set cluster join token add hvp_jointoken=XXX where XXX is the token (automatically generated only if not specified for server node 0 otherwise should be copied from /var/lib/rancher/rke2/server/token)
# Note: to set cluster join server add hvp_joinserver=https://XXX:6443 where XXX is the FQDN or IP of an already joined server
# Packages and kernel arguments to be removed/replaced/added
default_removepkgs=""
default_replacepkgs=""
default_addpkgs="tmux"
default_removekargs=""
default_replacekargs=""
default_addkargs=""
# Units to be masked/disabled/enabled
default_masksvcs=""
default_disablesvcs="podman.socket firewalld.service nm-cloud-setup.service nm-cloud-setup.timer"
default_enablesvcs="install-rke2.service"
# Custom parameters
default_nodetype="server"
default_nodeid=0
default_jointoken=""
default_joinserver=""

function pre_install_hook_custom_actions() {
	# Determine node type and index
	given_nodetype=$(sed -n -e 's/^.*hvp_nodetype=\(\S*\).*$/\1/p' /proc/cmdline)
	given_nodeid=$(sed -n -e 's/^.*hvp_nodeid=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_nodeid}" -a -z "${given_nodetype}" ]; then
		given_nodeid="${default_nodeid}"
		given_nodetype="${default_nodetype}"
	elif [ -z "${given_nodetype}" ]; then
		if [ "${given_nodeid}" -eq 0 ]; then
			given_nodetype="server"
		else
			given_nodetype="agent"
		fi
	elif [ -z "${given_nodeid}" ]; then
		if [ "${given_nodetype}" = "server" ]; then
			given_nodeid=0
		else
			given_nodeid=1
		fi
	fi
	# TODO: add logic for checking availability of the IPs (use mgmt network as canary) corresponding to the node ID chosen above and increment it until we find the first available one
}

function post_install_hook_custom_actions() {
	# Specialize server/agent node
	case "${given_nodetype}" in
		server)
			echo "Setting server role for RKE2 node" 1>&2
			rke2_options="server --selinux"
			;;
		*)
			# In any other case use agent as default type
			echo "Setting agent role for RKE2 node" 1>&2
			given_nodetype="agent"
			rke2_options="agent --selinux"
			;;
	esac
	
	# Determine cluster joining token
	given_jointoken=$(sed -n -e 's/^.*hvp_jointoken=\(\S*\).*$/\1/p' /proc/cmdline)
	case "${given_nodetype}" in
		server)
			if [ -z "${given_jointoken}" ]; then
				if [ -z "${default_jointoken}" ]; then
					if [ "${given_nodeid}" -eq 0 ]; then
						# Note: generating a random token if not given and this node is the first server node 
						given_jointoken=$(openssl rand -hex 16)
					else
						# Note: generating a forcibly invalid token if not given and this node is a further server/agent node 
						given_jointoken="set_actual_token_value_and_restart_rke2_service"
					fi
				else
					given_jointoken="${default_jointoken}"
				fi
			fi
			if [ "${given_nodeid}" -eq 0 ]; then
				default_enablesvcs="${default_enablesvcs} configure-rke2.service"
			fi
			rke2_service="rke2-server"
			;;
		agent)
			# In case of unrecognized/unsupported indication use agent as default type
			if [ -z "${given_jointoken}" ]; then
				if [ -z "${default_jointoken}" ]; then
					# Note: generating a forcibly invalid token if not given and this node is an agent node 
					given_jointoken="set_actual_token_value_and_restart_rke2_service"
				else
					given_jointoken="${default_jointoken}"
				fi
			fi
			rke2_service="rke2-agent"
			;;
	esac
	rke2_options="${rke2_options} --token=${given_jointoken}"
	
	# Determine cluster joining server
	given_joinserver=$(sed -n -e 's/^.*hvp_joinserver=\(\S*\).*$/\1/p' /proc/cmdline)
	if [ -z "${given_joinserver}" ]; then
		if [ -z "${default_joinserver}" ]; then
			given_joinserver="set.actual.join.server.fqdn.and.restart.rke2.service"
		else
			given_joinserver="${default_joinserver}"
		fi
	fi
	if [ "${given_nodetype}" = "agent" -o  "${given_nodetype}" = "server" -a "${given_nodeid}" -ne 0 ]; then
		rke2_options="${rke2_options} --server=${given_joinserver}"
	fi
	
	# Generate dynamic configuration files

	# Add NetworkManager configuration to avoid interfering with CNI-created interfaces
	cat <<- EOF > "/mnt/${ostree_path}/etc/NetworkManager/conf.d/rke2.conf"
	[keyfile]
	unmanaged-devices=interface-name:cali*;interface-name:flannel*
	EOF
	chown root:root "/mnt/${ostree_path}/etc/NetworkManager/conf.d/rke2.conf"
	chmod 644 "/mnt/${ostree_path}/etc/NetworkManager/conf.d/rke2.conf"

	# Add systemd unit override to force commandline in analogy with K3s EXEC parameter
	mkdir -p "/mnt/${ostree_path}/etc/systemd/system/${rke2_service}.service.d"
	cat <<- EOF > "/mnt/${ostree_path}/etc/systemd/system/${rke2_service}.service.d/override-commandline.conf"
	[Service]
	ExecStart=
	ExecStart=/usr/local/bin/rke2 ${rke2_options}
	EOF
	chown root:root "/mnt/${ostree_path}/etc/systemd/system/${rke2_service}.service.d/override-commandline.conf"
	chmod 644 "/mnt/${ostree_path}/etc/systemd/system/${rke2_service}.service.d/override-commandline.conf"
	
	# Add configuration file required by install-rke2.service and configure-rke2.service
	# TODO: add kernel commandline parameters to allow overriding all values below
	cat <<- EOF > "/mnt/${ostree_path}/etc/sysconfig/rke2-settings"
	# Define RKE2 configuration parameters
	# Note: newer Helm versions complain loudly if set to 644 - verify whether 644 is actually needed for Rancher registration
	RKE2_KUBECONFIG_MODE="600"
	INSTALL_RKE2_CHANNEL="stable"
	INSTALL_RKE2_VERSION="v1.29.6+rke2r1"
	INSTALL_RKE2_TYPE="${given_nodetype}"
	# Note: forcing use of tar instead of rpm to ease upgrading/maintenance (avoid layering)
	INSTALL_RKE2_METHOD="tar"
	INSTALL_RKE2_TAR_PREFIX="/usr/local"
	# Note: Helm tries to find HOME for storing cache/config - setting here since systemd removes it from env
	HOME="/root"
	# Note: Helm cannot not find cluster connection config from environment variable - setting here since systemd removes it from env
	KUBECONFIG="/etc/rancher/rke2/rke2.yaml"
	INSTALL_ETCDCTL_VERSION="v3.5.14"
	INSTALL_HELM_VERSION="3.15.3"
	INSTALL_METALLB_VERSION="0.14.2"
	INSTALL_CERTMANAGER_VERSION="1.14.5"
	INSTALL_CERTMANAGER_VERIFIER_VERSION="0.3.0"
	INSTALL_RANCHER_CHANNEL="latest"
	# TODO: disabling since latest released Rancher is incompatible with Kubernetes >= 1.29
	#INSTALL_RANCHER_VERSION="^2.8.5"
	INSTALL_RANCHER_VERSION=""
	INSTALL_RANCHERCLI_VERSION="2.8.4"
	INSTALL_OPENEBSLOCAL_VERSION="4.0.1"
	INSTALL_OPENEBSLOCAL_VG="${localst_actual_vg_name}"
	# Adding further dynamically deduced parameters
	RANCHER_HOSTNAME="rancher.mgmt.private"
	EOF
	chown root:root "/mnt/${ostree_path}/etc/sysconfig/rke2-settings"
	chmod 644 "/mnt/${ostree_path}/etc/sysconfig/rke2-settings"

	# Add specialized installation unit
	cat <<- EOF > "/mnt/${ostree_path}/etc/systemd/system/install-rke2.service"
	[Unit]
	Description=Install RKE2
	# Run after required RPM dependencies have been installed
	After=network-online.target setup-kargs.service
	Requires=network-online.target setup-kargs.service
	# Do not execute anymore if it was already installed
	ConditionPathExists=!/var/lib/%N.stamp
	
	[Service]
	Type=oneshot
	TimeoutStartSec=infinity
	EnvironmentFile=/etc/sysconfig/rke2-settings
	ExecStart=/usr/bin/bash -c '/usr/bin/curl -sfL https://get.rke2.io | /usr/bin/sh -'
	# TODO: RKE2 installation logic does not move the units to the proper place
	ExecStartPost=/usr/bin/bash -c '/usr/bin/mv -f /usr/local/lib/systemd/system/rke2-* /etc/systemd/system/'
	ExecStartPost=/usr/bin/bash -c '/usr/sbin/restorecon -v /etc/systemd/system/rke2-*'
	ExecStartPost=/usr/bin/systemctl daemon-reload
	# Note: RKE2 creates some needed dirs/files only on first execution
	ExecStartPost=/usr/bin/systemctl --now enable ${rke2_service}.service
	# Note: kubectl link does not get automatically created
	ExecStartPost=/usr/bin/ln -sf /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
	ExecStartPost=/usr/bin/bash -c '/usr/local/bin/kubectl completion bash > /etc/bash_completion.d/kubectl'
	# Note: crictl link does not get automatically created
	ExecStartPost=/usr/bin/ln -sf /var/lib/rancher/rke2/bin/crictl /usr/local/bin/crictl
	ExecStartPost=/usr/bin/bash -c '/usr/local/bin/crictl completion bash > /etc/bash_completion.d/crictl'
	# Note: ctr link does not get automatically created
	ExecStartPost=/usr/bin/ln -sf /var/lib/rancher/rke2/bin/ctr /usr/local/bin/ctr
	# Note: no bash completion support seems present in ctr
	#ExecStartPost=/usr/bin/bash -c '/usr/local/bin/ctr completion bash > /etc/bash_completion.d/ctr'
	# TODO: on agent nodes the kubeconfig file is not available - find a workaround
	ExecStartPost=/usr/bin/bash -c '/usr/bin/echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" > /etc/profile.d/rke2.sh'
	ExecStartPost=/usr/bin/bash -c '/usr/bin/echo "setenv KUBECONFIG /etc/rancher/rke2/rke2.yaml" > /etc/profile.d/rke2.csh'
	ExecStartPost=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/etcd-io/etcd/releases/download/\${INSTALL_ETCDCTL_VERSION}/etcd-\${INSTALL_ETCDCTL_VERSION}-linux-amd64.tar.gz | /usr/bin/tar xOzf - etcd-\${INSTALL_ETCDCTL_VERSION}-linux-amd64/etcdctl > /usr/local/bin/etcdctl'
	ExecStartPost=/usr/bin/chmod a+rx /usr/local/bin/etcdctl
	ExecStartPost=/usr/bin/bash -c '/usr/bin/curl -sfL https://get.helm.sh/helm-v\${INSTALL_HELM_VERSION}-linux-amd64.tar.gz | /usr/bin/tar xOzf - linux-amd64/helm > /usr/local/bin/helm'
	ExecStartPost=/usr/bin/chmod a+rx /usr/local/bin/helm
	ExecStartPost=/usr/bin/bash -c '/usr/local/bin/helm completion bash > /etc/bash_completion.d/helm'
	ExecStartPost=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/jetstack/cert-manager/releases/download/v\${INSTALL_CERTMANAGER_VERSION}/cert-manager-cmctl-linux-amd64.tar.gz | /usr/bin/tar xOzf - cmctl > /usr/local/bin/cmctl'
	ExecStartPost=/usr/bin/chmod a+rx /usr/local/bin/cmctl
	ExecStartPost=/usr/bin/bash -c '/usr/local/bin/cmctl completion bash > /etc/bash_completion.d/cmctl'
	ExecStartPost=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/alenkacz/cert-manager-verifier/releases/download/v\${INSTALL_CERTMANAGER_VERIFIER_VERSION}/cert-manager-verifier_\${INSTALL_CERTMANAGER_VERIFIER_VERSION}_Linux_x86_64.tar.gz | /usr/bin/tar xOzf - cm-verifier > /usr/local/bin/cm-verifier'
	ExecStartPost=/usr/bin/chmod a+rx /usr/local/bin/cm-verifier
	ExecStartPost=/usr/bin/bash -c '/usr/bin/curl -sfL https://github.com/rancher/cli/releases/download/v\${INSTALL_RANCHERCLI_VERSION}/rancher-linux-amd64-v\${INSTALL_RANCHERCLI_VERSION}.tar.gz | /usr/bin/tar xOzf - ./rancher-v\${INSTALL_RANCHERCLI_VERSION}/rancher > /usr/local/bin/rancher'
	ExecStartPost=/usr/bin/chmod a+rx /usr/local/bin/rancher
	ExecStartPost=/usr/bin/touch /var/lib/%N.stamp
	
	[Install]
	WantedBy=multi-user.target
	EOF
	chown root:root "/mnt/${ostree_path}/etc/systemd/system/install-rke2.service"
	chmod 644 "/mnt/${ostree_path}/etc/systemd/system/install-rke2.service"

	# Note: specific configuration files and the configuration service should be created only on the first server node
	if [ "${given_nodetype}" = "server" -a "${given_nodeid}" -eq 0 ]; then
		# TODO: Determine the URL of the first server node
		
		# TODO: Determine the MetalLB address pool
		
		# TODO: Determine the FQDN of the Rancher service
		
		# Add configuration file for MetalLB
		# TODO: make the address pool and interface names dinamically configurable/discoverable
		mkdir -p "/mnt/${ostree_path}/etc/rancher/rke2"
		cat <<- EOF > "/mnt/${ostree_path}/etc/rancher/rke2/metallb-config.yaml"
		apiVersion: metallb.io/v1beta1
		kind: IPAddressPool
		metadata:
		  name: production
		spec:
		  addresses:
		  - 192.168.48.40-192.168.48.49
		---
		apiVersion: metallb.io/v1beta1
		kind: L2Advertisement
		metadata:
		  name: production
		spec:
		  ipAddressPools:
		  - production
		  interfaces:
		  - ens192
		EOF
		chown root:root "/mnt/${ostree_path}/etc/rancher/rke2/metallb-config.yaml"
		chmod 644 "/mnt/${ostree_path}/etc/rancher/rke2/metallb-config.yaml"
	
		# Add configuration file for OpenEBS
		mkdir -p "/mnt/${ostree_path}/etc/rancher/rke2"
		cat <<- EOF > "/mnt/${ostree_path}/etc/rancher/rke2/openebs-config.yaml"
		apiVersion: storage.k8s.io/v1
		kind: StorageClass
		metadata:
		  name: local-path
		  annotations:
		    storageclass.kubernetes.io/is-default-class: "false"
		---
		apiVersion: storage.k8s.io/v1
		kind: StorageClass
		metadata:
		  name: openebs-lvmpv
		  annotations:
		    storageclass.kubernetes.io/is-default-class: "true"
		parameters:
		  storage: "lvm"
		  volgroup: "${localst_actual_vg_name}"
		provisioner: local.csi.openebs.io
		EOF
		chown root:root "/mnt/${ostree_path}/etc/rancher/rke2/openebs-config.yaml"
		chmod 644 "/mnt/${ostree_path}/etc/rancher/rke2/openebs-config.yaml"
	
		# Add configuration file for Rancher
		# TODO: make the Rancher hostname and number of replicas dinamically configurable/discoverable
		mkdir -p "/mnt/${ostree_path}/etc/rancher/rke2"
		cat <<- EOF > "/mnt/${ostree_path}/etc/rancher/rke2/rancher-values.yaml"
		hostname: rancher.mgmt.private
		ingress:
		  extraAnnotations:
		    kubernetes.io/ingress.class: "nginx"
		replicas: 1
		EOF
		chown root:root "/mnt/${ostree_path}/etc/rancher/rke2/rancher-values.yaml"
		chmod 644 "/mnt/${ostree_path}/etc/rancher/rke2/rancher-values.yaml"
	
		# Add specialized configuration unit
		cat <<- EOF > "/mnt/${ostree_path}/etc/systemd/system/configure-rke2.service"
		[Unit]
		Description=Configure RKE2 and further required components
		# Run after required RPM dependencies have been installed and RKE2 has been installed
		After=network-online.target install-rke2.service
		Requires=network-online.target install-rke2.service
		# Execute only when manually allowed
		ConditionPathExists=/etc/sysconfig/configure-rke2.allowed
		# Do not execute anymore if it was already installed
		ConditionPathExists=!/var/lib/%N.stamp
		
		[Service]
		Type=oneshot
		TimeoutStartSec=infinity
		EnvironmentFile=/etc/sysconfig/rke2-settings
		# TODO: configure CoreDNS for external names resolution with k8s_gateway plugin
		# TODO: add Zitadel deployment
		# TODO: add OpenEBS-Mayastor/MinIO
		# TODO: add Nextcloud deployment
		# TODO: add optional KubeVirt deployment (add MultusCNI in base RKE2 installation)
		ExecStart=/usr/local/bin/helm repo add metallb https://metallb.github.io/metallb
		ExecStartPost=/usr/local/bin/helm repo add jetstack https://charts.jetstack.io
		ExecStartPost=/usr/local/bin/helm repo add openebs https://openebs.github.io/openebs
		ExecStartPost=/usr/local/bin/helm repo add rancher-\${INSTALL_RANCHER_CHANNEL} https://releases.rancher.com/server-charts/\${INSTALL_RANCHER_CHANNEL}
		ExecStartPost=/usr/local/bin/helm repo update
		ExecStartPost=/usr/local/bin/helm install metallb metallb/metallb --create-namespace --namespace metallb-system --version \${INSTALL_METALLB_VERSION}
		ExecStartPost=/usr/local/bin/kubectl -n metallb-system rollout status deploy/metallb-controller
		ExecStartPost=/usr/local/bin/kubectl -n metallb-system apply -f /etc/rancher/rke2/metallb-config.yaml
		ExecStartPost=/usr/local/bin/helm install cert-manager jetstack/cert-manager --create-namespace --namespace cert-manager --version v\${INSTALL_CERTMANAGER_VERSION} --set installCRDs=true
		ExecStartPost=/usr/local/bin/kubectl -n cert-manager rollout status deploy/cert-manager
		ExecStartPost=/usr/local/bin/kubectl -n cert-manager rollout status deploy/cert-manager-webhook
		ExecStartPost=/usr/local/bin/cm-verifier --namespace cert-manager --timeout 900s
		ExecStartPost=/usr/bin/bash -c '/usr/bin/test "x\${INSTALL_OPENEBSLOCAL_VG}" != "x" && /usr/local/bin/helm install openebs openebs/openebs --create-namespace --namespace openebs --version \${INSTALL_OPENEBSLOCAL_VERSION} --set ndm.enabled=false --set localpv.enabled=false --set zfs-localpv.enabled=false --set mayastor.enabled=false --set engines.local.zfs.enabled=false --set engines.replicated.mayastor.enabled=false || true'
		ExecStartPost=/usr/bin/bash -c '/usr/bin/test "x\${INSTALL_OPENEBSLOCAL_VG}" != "x" && /usr/local/bin/kubectl -n openebs rollout status deploy/openebs-localpv-provisioner || true'
		ExecStartPost=/usr/bin/bash -c '/usr/bin/test "x\${INSTALL_OPENEBSLOCAL_VG}" != "x" && /usr/local/bin/kubectl -n openebs rollout status deploy/openebs-lvm-localpv-controller || true'
		ExecStartPost=/usr/bin/bash -c '/usr/bin/test "x\${INSTALL_OPENEBSLOCAL_VG}" != "x" && /usr/local/bin/kubectl -n openebs apply -f /etc/rancher/rke2/openebs-config.yaml || true'
		# TODO: debug rancher ingress/TLS problems
		ExecStartPost=/usr/bin/bash -c '/usr/bin/test "x\${INSTALL_RANCHER_VERSION}" != "x" && /usr/local/bin/helm install rancher rancher-\${INSTALL_RANCHER_CHANNEL}/rancher --create-namespace --namespace cattle-system --version \${INSTALL_RANCHER_VERSION} --values /etc/rancher/rke2/rancher-values.yaml || true'
		ExecStartPost=/usr/bin/bash -c '/usr/bin/test "x\${INSTALL_RANCHER_VERSION}" != "x" && /usr/local/bin/kubectl -n cattle-system rollout status deploy/rancher || true'
		ExecStartPost=/usr/bin/touch /var/lib/%N.stamp
		
		[Install]
		WantedBy=multi-user.target
		EOF
		chown root:root "/mnt/${ostree_path}/etc/systemd/system/configure-rke2.service"
		chmod 644 "/mnt/${ostree_path}/etc/systemd/system/configure-rke2.service"
	fi
}
