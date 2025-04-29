#!/bin/bash
# Script to customize the additional component YAML configuration files inside the specified directory
# Note: it is assumed that template files are present in a "tpl" subdirectory of the given configuration directory

# Verify templates directory existence 
configuration_dir="$1"
templates_dir="$1/tpl"
if [ ! -d "${templates_dir}" ]; then
    echo "Fatal: configuration templates directory ${templates_dir} not found - exiting." 1>&2
    exit 255
fi

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

# Derive configuration parameters
last_address="$(ipmat ${FIRST_ADDRESS} $((ADDRESSES_TO_TRY -1)) +)"
cp_nodes_number=$(/usr/local/bin/kubectl get nodes --selector 'node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name --no-headers | wc -l)
nodes_number=$(/usr/local/bin/kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers | wc -l)
nodes_list=$(/usr/local/bin/kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers)
# Fail on an even number of control plane nodes
if [ $((cp_nodes_number % 2)) -eq 0 ]; then
    echo "Fatal: invalid number of nodes: ${nodes_number} - exiting." 1>&2
    exit 254
else
    quorum_number=$((cp_nodes_number / 2 + 1))
fi
if [ "${cp_nodes_number}" -eq 1 ]; then
    replica_number=1
else
    replica_number=2
fi
echo "Found ${nodes_number} nodes total and ${cp_nodes_number} control-plane nodes with quorum at ${quorum_number} and replica at ${replica_number}" 1>&2
unset node
declare -a node
i=0
for node_name in ${nodes_list}; do
    node[${i}]="${node_name}"
    i=$((i+1))
done
if [ ${i} -lt 3 ]; then
    node[2]="undefined"
    node[1]="undefined"
fi

# Automatically detect the loadbalanced K8s control-plane service IP address
if [ -z "${LBCONTROLPLANEIP}" ]; then
    # TODO: detect whether the controlplane IP is already configured in Kube-VIP
    # Cycle on all possible IPs to find the first one free
    # Note: starting from top down in order to leave room to continguous expansion for nodes
    for index in $(seq 0 $((ADDRESSES_TO_TRY - 1))) ; do
        tentative_ipaddr=$(ipmat ${last_address} ${index} -)
        # Skip gateway IP address
        if [ "${tentative_ipaddr}" = "${GATEWAY_ADDRESS}" ]; then
            continue
        fi
        ping -c 3 -w 8 -i 2 "${tentative_ipaddr}" > /dev/null 2>&1
        res=$?
        if [ ${res} -ne 0 ]; then
            LBCONTROLPLANEIP="${tentative_ipaddr}"
            break
        fi
    done
fi
echo "Loadbalanced K8s API service IP set at ${LBCONTROLPLANEIP}" 1>&2

# Automatically detect the loadbalanced services IP range
# TODO: support discovery and configuration of multiple disjoint ranges and single IPs
if [ -z "${LBIPRANGE}" ]; then
    # TODO: detect whether the services IP range is already configured in Kube-VIP
    # Cycle on all possible IPs to find the first and last one free
    # Note: starting from top down to be adjacent to the loadbalanced K8s control-plane service IP address defined above
    range_low_ip=""
    range_high_ip=""
    for index in $(seq 0 $((ADDRESSES_TO_TRY - 1))) ; do
        tentative_ipaddr=$(ipmat ${last_address} ${index} -)
        ping -c 3 -w 8 -i 2 "${tentative_ipaddr}" > /dev/null 2>&1
        res=$?
        # Note: ping failed means IP address is free
        if [ ${res} -ne 0 ]; then
            # Check whether we had already found the upper bound or not
            if [ -z "${range_high_ip}" ]; then
                # Upper bound still not found - check and set it now
                # Skip gateway IP address
                if [ "${tentative_ipaddr}" = "${GATEWAY_ADDRESS}" ]; then
                    continue
                fi
                # Skip controlplane IP address
                if [ "${tentative_ipaddr}" = "${LBCONTROLPLANEIP}" ]; then
                    continue
                fi
                range_high_ip="${tentative_ipaddr}"
                # When we define the upper bound we initialize also the lower one, then we will try to move it down
                range_low_ip="${tentative_ipaddr}"
                continue
            else
                # Upper bound already found - check and move down the lower bound now
                # Skip gateway IP address
                if [ "${tentative_ipaddr}" = "${GATEWAY_ADDRESS}" ]; then
                    break
                fi
                # Skip controlplane IP address
                if [ "${tentative_ipaddr}" = "${LBCONTROLPLANEIP}" ]; then
                    break
                fi
                range_low_ip="${tentative_ipaddr}"
                continue
            fi
        else
           # Note: ping succeeded means IP address is taken - skip it and try with the next one
            break
        fi
    done
    LBIPRANGE="${range_low_ip}-${range_high_ip}"
fi
echo "Loadbalanced application services IP range set at ${LBIPRANGE}" 1>&2

# Automatically assign the DNS service IP
if [ -z "${LBDNSIP}" ]; then
    # TODO: detect whether the DNS service IP is already configured in custom CoreDNS
    LBDNSIP="${range_high_ip}"
fi
echo "External DNS service IP set at ${LBDNSIP}" 1>&2

# Perform parameter substitution inside configuration files
# TODO: rewrite to use dynamically generated variable names based on the __HVP_XXX_HVP__ strings dynamically found in the files under templates_dir
# TODO: remove the __HVP_ prefix and _HVP__ suffix from variable names whose value must be deduced by this script and not saved in or read from k8s-settings
for template_file in "${templates_dir}"/*.yaml ; do
    if [ -f "${template_file}" ]; then
	configuration_file="${configuration_dir}/$(/usr/bin/basename "${template_file}")"
        /usr/bin/sed \
            -e "s/__HVP_CURRENT_FCOS_VERSION_HVP__/${SUC_CURRENT_FCOS_VERSION}/g" \
            -e "s>__HVP_TIMEZONE_HVP__>${GIVEN_TIMEZONE}>g" \
            -e "s/__HVP_MAIN_INTERFACE_HVP__/${MAIN_INTERFACE}/g" \
            -e "s/__HVP_DOMAINNAME_HVP__/${GIVEN_DOMAINNAME}/g" \
            -e "s/__HVP_NAMESERVERS_HVP__/$(echo "${GIVEN_NAMESERVERS}" | sed -e 's/,/ /g')/g" \
            -e "s/__HVP_CONTROL_PLANE_IP_HVP__/${LBCONTROLPLANEIP}/g" \
            -e "s/__HVP_SERVICES_IP_RANGE_HVP__/${LBIPRANGE}/g" \
            -e "s/__HVP_DNS_IP_HVP__/${LBDNSIP}/g" \
            -e "s/__HVP_LOCALST_ENABLED_HVP__/$(test "x${LOCALST_VGNAME}" != "x" && echo "true" || echo "false")/g" \
            -e "s/__HVP_REPLICATEDST_ENABLED_HVP__/$(test "x${REPLICATEDST_DISKNAME}" != "x" && echo "true" || echo "false")/g" \
            -e "s/__HVP_LOCALST_VGNAME_HVP__/${LOCALST_VGNAME}/g" \
            -e "s/__HVP_REPLICATEDST_DISKNAME_HVP__/${REPLICATEDST_DISKNAME}/g" \
            -e "s/__HVP_NODES_NUMBER_HVP__/${nodes_number}/g" \
            -e "s/__HVP_REPLICA_NUMBER_HVP__/${replica_number}/g" \
            -e "s/__HVP_QUORUM_NUMBER_HVP__/${quorum_number}/g" \
            -e "s/__HVP_NODE_ZERO_HVP__/${node[0]}/g" \
            -e "s/__HVP_NODE_ONE_HVP__/${node[1]}/g" \
            -e "s/__HVP_NODE_TWO_HVP__/${node[2]}/g" \
        "${template_file}" > "${configuration_file}"
        chown root:root "${configuration_file}"
        chmod 600 "${configuration_file}"
    fi
done

# Save back the already discovered and configured values
# TODO: rewrite to use dynamically generated variable names based on the __HVP_XXX_HVP__ strings dynamically found in the files under templates_dir
sed -i \
    -e "/^LBDNSIP=/s/=.*$/=\"${LBDNSIP}\"/" \
    -e "/^LBIPRANGE=/s/=.*$/=\"${LBIPRANGE}\"/" \
    -e "/^LBCONTROLPLANEIP=/s/=.*$/=\"${LBCONTROLPLANEIP}\"/" \
/etc/sysconfig/k8s-environment

# Perform symbolic linking of files with multiple versions depending on the number of nodes
if [ ${nodes_number} -ge 3 ]; then
    for configuration_file in "${configuration_dir}"/*-3-nodes.yaml ; do
        link_name=$(echo "${configuration_file}" | sed -e 's/-3-nodes//g')
        ln -sf "${configuration_file}" "${link_name}"
    done
elif [ ${nodes_number} -eq 1 ]; then
    for configuration_file in "${configuration_dir}"/*-1-node.yaml ; do
        link_name=$(echo "${configuration_file}" | sed -e 's/-1-node//g')
        ln -sf "${configuration_file}" "${link_name}"
    done
fi

