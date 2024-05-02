#!/bin/bash
# Script to execute from your local machine to deploy CRC and OpenStack.
# Requires the following:
# - SSH access to the remote server
# - The remote server must have git installed
# - The remote server should be CentOS 9 Stream (what I test)
# - The remote server should have a user named "stack" with sudo privileges (can be changed in the script)
# - A file named ~/.ocp-pull-secret.txt with the pull secret for OpenShift on your local machine

REMOTE_SERVER="foch.macchi.pro"
REMOTE_USER="stack"

# SSH prefix command
SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $REMOTE_USER@$REMOTE_SERVER"

# Install EPEL repository
$SSH_CMD "sudo dnf config-manager --set-enabled crb && sudo dnf install -y epel-release epel-next-release"

# Install base packages for our needs
$SSH_CMD "sudo dnf install -y ansible make python-pip"

# Clone install_yamls
$SSH_CMD "git clone https://github.com/openstack-k8s-operators/install_yamls.git"

# Copy the secret file
scp ~/.ocp-pull-secret.txt $REMOTE_USER@$REMOTE_SERVER:install_yamls/devsetup/pull-secret.txt

# Run this block through SSH
$SSH_CMD << 'EOF'
cd install_yamls/devsetup
make download_tools
CPUS=12 MEMORY=25600 DISK=100 make crc
eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
make crc_attach_default_interface
EDPM_TOTAL_NODES=1 make edpm_compute 
cd ..
make crc_storage
make input
make openstack
make openstack_deploy
sleep 20m
DATAPLANE_TOTAL_NODES=1 make edpm_wait_deploy
EOF