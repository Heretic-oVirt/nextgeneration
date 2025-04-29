#!/bin/bash
# Script to check whether a reboot to enact a pending Fedora CoreOS upgrade (performed by System Update Controller) is needed
# Note: currently only K3s/addons upgrades are checked to inhibit kured-based reboots - the other way round (K3s/addons that do not start if kured-based reboots are happening) is currently ignored
# TODO: find a way to put a label on each node before rebooting it and removing it afterwards then check that label before performing K3s/addons upgrades - workaround by manually maintaining time separation, possible since since reboots happen only inside a specific time-window
# Retrieve the labels attached to the current node
node_labels=$(kubectl get nodes $(awk '{print tolower($0)}' /etc/hostname) -o json | jq '.metadata.labels')
# Deny reboot if a K3s upgrade (performed by System Update Controller) is still running
echo "${node_labels}" | grep -wq 'hvp\.io/k3s-upgrade' && exit 253
# Deny reboot if an addons upgrade (performed by a manually-started systemd unit) is still running
echo "${node_labels}" | grep -wq 'hvp\.io/k8s-upgrade' && exit 254
# Request reboot if there are rpm-ostree pending changes or deny it otherwise
/usr/bin/rpm-ostree status --pending-exit-77 && exit 255 || exit 0
