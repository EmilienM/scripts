#!/bin/bash
# Apply what's documented here: https://github.com/openstack-k8s-operators/install_yamls/tree/main?tab=readme-ov-file#deploy-dev-env-using-crc-edpm-nodes-with-isolated-networks
#
# Script to execute from your local machine to deploy CRC and OpenStack.
# Requires the following:
# - SSH access to the remote server
# - The remote server must have git installed
# - The remote server should be CentOS 9 Stream (what I test)
# - The remote server should have a user named "stack" with sudo privileges (can be changed in the script)
# - A file named ~/.ocp-pull-secret.txt with the pull secret for OpenShift on your local machine

set -x

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
EDPM_COMPUTE_VCPUS=16 EDPM_COMPUTE_RAM=72 EDPM_COMPUTE_DISK_SIZE=200 EDPM_TOTAL_NODES=1 make edpm_compute 
cd ..
make crc_storage
make input
make openstack
make openstack_deploy
sleep 20m
DATAPLANE_TOTAL_NODES=1 DATAPLANE_TIMEOUT=40m make edpm_wait_deploy
sudo iptables -D LIBVIRT_FWO 3
sudo iptables -D LIBVIRT_FWI 3
EOF

# here you need to handle clouds.yaml manually for now
export OS_CLOUD=rhoso
openstack project create shiftstack
openstack user create --project shiftstack --password secrete shiftstack
openstack role add --user shiftstack --project shiftstack member

openstack flavor create --ram 32768 --disk 50 --vcpu 8 --public CPU_8_Memory_32768_Disk_50

openstack quota set --cores 120 --fixed-ips -1 --injected-file-size -1 --injected-files -1 --instances -1 --key-pairs -1 --properties -1 --ram 450000 --gigabytes 4000 --server-groups -1 --server-group-members -1 --backups -1 --backup-gigabytes -1 --per-volume-gigabytes -1 --snapshots -1 --volumes -1 --floating-ips 80 --secgroup-rules -1 --secgroups -1 --networks -1 --subnets -1 --ports -1 --routers -1 --rbac-policies -1 --subnetpools -1 shiftstack

openstack network create public --external --provider-network-type flat --provider-physical-network datacentre
openstack subnet create pub_sub --subnet-range 192.168.122.0/24 --allocation-pool start=192.168.122.200,end=192.168.122.210 --gateway 192.168.122.1 --no-dhcp --network public

openstack security group create allow_ssh --project shiftstack
openstack security group rule create --protocol tcp --dst-port 22 --project shiftstack allow_ssh

openstack security group create allow_ping --project shiftstack
openstack security group rule create --protocol icmp --project shiftstack allow_ping
openstack security group rule create --protocol ipv6-icmp --project shiftstack allow_ping

openstack image show centos9-stream || wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 && openstack image create --public --disk-format qcow2 --file CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 centos9-stream && rm -f CentOS-Stream-*

export OS_CLOUD=rhoso_shiftstack
openstack keypair show default_key || openstack keypair create --public-key ~/.ssh/id_rsa.pub default_key
