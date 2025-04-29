#!/bin/bash
# Script to perform an rpm-ostree deployment of a specific Fedora CoreOS version through System-Update-Controller (SUC) with reboot demanded to Kured
# Note: derived from https://github.com/coreos/fedora-coreos-tracker/issues/536#issue-637082353
exec 2>&1
set -e -o pipefail

# No need to lock since CoreOS upgrade can be always freely performed - actual kured-based reboot is separately locked

# Detect the versions/status
booted_status=$(rpm-ostree status --booted --json | jq '.deployments[]')
current_os_checksum=$(echo "${booted_status}" | jq -r 'select(.booted==true).checksum')
current_os_version=$(echo "${booted_status}" | jq -r 'select(.booted==true).version')
secrets=$(dirname $0)
target_os_version=$(cat ${secrets}/targetVersion)

echo "Checking for upgrade from '${current_os_checksum}/${current_os_version}' to '${target_os_version}'"

# Check whether no upgrade version was specified or it was the same as the running version
if [ -n "${target_os_version}" -a "${target_os_version}" != "${current_os_version}" ]; then
  echo "Upgrading from ${current_os_checksum}/${current_os_version} to '${target_os_version}'"
  # Check whether the target version has already been installed but is simply not running yet
  next_version_present=$(echo "${booted_status}" | jq -r "select(.version==\"${target_os_version}\")")
  if [ -n "${next_version_present}" ]; then
    rpm-ostree deploy version="${target_os_version}"
    # Keep the current Fedora CoreOS version aligned in the environment variables file
    if [ -f /etc/sysconfig/k8s-addons ]; then
      sed -i -e "/^SUC_CURRENT_FCOS_VERSION=/s/=.*\$/=\"${target_os_version}\"/" -e "/^SUC_TARGET_FCOS_VERSION=/s/=.*\$/=\"${target_os_version}\"/" /etc/sysconfig/k8s-addons
    fi
  else
    echo "Upgrade already installed - waiting for Kured to reboot"
  fi
else
  echo "No upgrade available/needed - skipping"
fi
