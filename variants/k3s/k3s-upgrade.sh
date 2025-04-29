#!/bin/bash
# Script to perform a phased K3s and base utilities upgrade through System-Update-Controller (SUC)
# Note: This script takes advantage of the fact that the install-k3s.service logic can perform both the initial installation and regular upgrades
exec 2>&1
set -e -o pipefail

# Lock to avoid kured-based rebooting with upgrade still in progress
kubectl label nodes $(awk '{print tolower($0)}' /etc/hostname) --overwrite hvp.io/k3s-upgrade=true

# Retrieve all the versions from the secret
secrets=$(dirname $0)
given_k3schannel=$(cat ${secrets}/k3sChannel)
given_k3sversion=$(cat ${secrets}/k3sVersion)
given_etcdctlversion=$(cat ${secrets}/etcdctlVersion)
given_helmversion=$(cat ${secrets}/helmVersion)

# Update in place the version variables inside the k3s-settings file using the values from the secret retrieved above
# Note: this step makes sure that even if the versions inside k3s-settings are manually updated only on one node (from which the configure-k8s service gets started), they get propagated to all nodes
sed -i \
  -e '/^INSTALL_K3S_CHANNEL/s/=.*$/="'${given_k3schannel}'"/' \
  -e '/^INSTALL_K3S_VERSION/s/=.*$/="'${given_k3sversion}'"/' \
  -e '/^INSTALL_ETCDCTL_VERSION/s/=.*$/="'${given_etcdctlversion}'"/' \
  -e '/^INSTALL_HELM_VERSION/s/=.*$/="'${given_helmversion}'"/' \
  /etc/sysconfig/k3s-settings

# Remove the completion file checked by the install-k3s service
rm -f /var/lib/install-k3s.stamp

# Start the install-k3s service and wait for it to end
systemctl --wait start install-k3s.service

# Remove lock to allow kured-based rebooting
kubectl label nodes $(awk '{print tolower($0)}' /etc/hostname) --overwrite hvp.io/k3s-upgrade-
