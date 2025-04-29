#!/bin/bash
# Script to check whether all K3s server nodes have already been upgraded to the expected version
# Note: This script will be run on agent nodes only
exec 2>&1
set -e -o pipefail

# Retrieve the expected target K3s version from the secret
secrets=$(dirname $0)
given_k3sversion=$(cat ${secrets}/k3sVersion)

# Check the number of expected control-plane nodes and verify whether they are all ready and running the expected target K3s version
cp_total_nodes_number=$(/usr/local/bin/kubectl get nodes --selector 'node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name --no-headers | wc -l)
cp_upgraded_nodes_number=$(/usr/local/bin/kubectl get nodes --selector 'node-role.kubernetes.io/control-plane' -o json | jq -r ".items[] | select(.status.conditions[].reason==\"KubeletReady\" and .status.nodeInfo.kubeletVersion==\"${given_k3sversion}\").metadata.name" | wc -l)
if [ ${cp_total_nodes_number} -eq ${cp_upgraded_nodes_number} ]; then
  exit 0
else
  exit 255
fi
