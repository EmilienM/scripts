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

set -e

if [ "$EUID" -eq 0 ]; then
  echo "This script must not be run as root"
  exit 1
fi

REMOTE_SERVER="foch.macchi.pro"
REMOTE_USER="stack"

# SSH prefix command
SSH_CMD="ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $REMOTE_USER@$REMOTE_SERVER"

# Install EPEL repository
$SSH_CMD "sudo dnf config-manager --set-enabled crb && sudo dnf install -y epel-release epel-next-release"

# Install base packages for our needs
$SSH_CMD "sudo dnf install -y ansible make python-pip"

$SSH_CMD "sudo dnf install -y https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.rpm"

# Clone install_yamls
$SSH_CMD "[ -d install_yamls ] || git clone https://github.com/openstack-k8s-operators/install_yamls.git"

# Workaround for the timeout
# https://github.com/openstack-k8s-operators/install_yamls/pull/853
$SSH_CMD "[ -d install_yamls ] || bash -c 'cd install_yamls; curl https://patch-diff.githubusercontent.com/raw/openstack-k8s-operators/install_yamls/pull/853.patch | git apply -v'"

# Copy the secret file
scp ~/.ocp-pull-secret.txt $REMOTE_USER@$REMOTE_SERVER:install_yamls/devsetup/pull-secret.txt

# sshuttle to access the remote networks
pkill sshuttle && sshuttle -D -r $REMOTE_USER@$REMOTE_SERVER 192.168.122.0/24 192.168.130.0/24

# Create the RHOSO deployment script that will be executed on the remote server
set +e
rm -f /tmp/rhoso.sh
cat << EOF >/tmp/rhoso.sh
#!/bin/bash
set -euo pipefail

cd ~/install_yamls/devsetup
make download_tools
CPUS=12 MEMORY=25600 DISK=100 make crc
eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
echo 'export PATH="/home/stack/.crc/bin/oc:$PATH"' >> ~/.bashrc
make crc_attach_default_interface
EDPM_COMPUTE_VCPUS=16 EDPM_COMPUTE_RAM=72 EDPM_COMPUTE_DISK_SIZE=230 EDPM_TOTAL_NODES=1 make edpm_compute 
make bmaas_route_crc_and_crc_bmaas_networks BMAAS_ROUTE_LIBVIRT_NETWORKS=default,crc
cd ..

TIMEOUT=30m make crc_storage openstack_wait openstack_wait_deploy

oc patch -n openstack openstackcontrolplane openstack-galera-network-isolation --type=merge --patch '
spec:
  horizon:
    enabled: true
  ovn:
    template:
      ovnController:
        nicMappings:
          datacentre: ospbr
          octavia: octbr
  octavia:
    enabled: true
    template:
      amphoraImageContainerImage: quay.io/gthiemonge/octavia-amphora-image
      apacheContainerImage: registry.redhat.io/rhel8/httpd-24:latest
      octaviaHousekeeping:
        networkAttachments:
          - octavia
      octaviaHealthManager:
        networkAttachments:
          - octavia
      octaviaWorker:
        networkAttachments:
          - octavia
    '

make edpm_wait_deploy || true

oc get secrets rootca-public -n openstack -o yaml | grep ca.crt | awk '{print $2}' | base64 --decode > /tmp/rhoso.crt

# Install NFS server, until I can easily deploy Ceph
sudo dnf -y install nfs-utils
sudo mkdir /opt/cinder_nfs
echo "/opt/cinder_nfs 192.168.0.0/16(rw,no_root_squash)" | sudo tee -a /etc/exports
sudo systemctl enable --now rpcbind nfs-server
sudo systemctl stop firewalld
sudo dnf install -y wget
wget https://raw.githubusercontent.com/openstack-k8s-operators/cinder-operator/main/config/samples/backends/nfs/cinder-volume-nfs-secrets.yaml -O /tmp/cinder-volume-nfs-secrets.yaml
NFS_HOST=$(hostname)
sed -i "s/192.168.130.1/${NFS_HOST}/g" /tmp/cinder-volume-nfs-secrets.yaml
sed -i "s/\/var\/nfs\/cinder/\/opt\/cinder_nfs/g" /tmp/cinder-volume-nfs-secrets.yaml
oc create -f /tmp/cinder-volume-nfs-secrets.yaml
oc patch -n openstack openstackcontrolplane openstack-galera-network-isolation --type=merge --patch '
spec:
  cinder:
    template:
      cinderVolumes:
        nfs:
          customServiceConfig: |
            [nfs]
            volume_backend_name=nfs
            volume_driver=cinder.volume.drivers.nfs.NfsDriver
            nfs_snapshot_support=true
            nas_secure_file_operations=false
            nas_secure_file_permissions=false
          customServiceConfigSecrets:
          - cinder-volume-nfs-secrets
          networkAttachments:
          - storage
          replicas: 1
          resources: {}
    '
EOF
set -e
scp /tmp/rhoso.sh $REMOTE_USER@$REMOTE_SERVER:~/rhoso.sh
$SSH_CMD "bash ~/rhoso.sh |& tee -a ~/rhoso.log"

# If you're not me, you don't want to go through the next steps.
if [ "$USER" != "emilien" ]; then
  echo "DONE..."
  exit 0
fi

scp $REMOTE_USER@$REMOTE_SERVER:/tmp/rhoso.crt ~/.config/openstack/rhoso.crt

export OS_CLOUD=rhoso
openstack volume type create nfs
openstack volume type set --property volume_backend_name=nfs nfs

openstack project create shiftstack
openstack user create --project shiftstack --password secrete shiftstack
openstack role add --user shiftstack --project shiftstack member

openstack flavor create --ram 32768 --disk 50 --vcpu 8 --public CPU_8_Memory_32768_Disk_50
openstack flavor create --ram 1024 --disk 10 --vcpu 1 --ephemeral 1 --public m1.tiny
openstack flavor create --ram 2048 --disk 15 --vcpu 1 --ephemeral 1 --public m1.small
openstack flavor create --ram 4096 --disk 20 --vcpu 2 --ephemeral 2 --public m1.medium
openstack flavor create --ram 8192 --disk 25 --vcpu 4 --ephemeral 5 --public m1.large
openstack flavor create --ram 16384 --disk 40 --vcpu 4 --ephemeral 10 --public m1.xlarge

openstack quota set --cores 120 --fixed-ips -1 --injected-file-size -1 --injected-files -1 --instances -1 --key-pairs -1 --properties -1 --ram 450000 --gigabytes 4000 --server-groups -1 --server-group-members -1 --backups -1 --backup-gigabytes -1 --per-volume-gigabytes -1 --snapshots -1 --volumes -1 --floating-ips 10 --secgroup-rules -1 --secgroups -1 --networks -1 --subnets -1 --ports -1 --routers -1 --rbac-policies -1 --subnetpools -1 shiftstack

openstack network create public --external --provider-network-type flat --provider-physical-network datacentre
openstack subnet create pub_sub --subnet-range 192.168.122.0/24 --allocation-pool start=192.168.122.200,end=192.168.122.210 --gateway 192.168.122.1 --no-dhcp --network public

openstack floating ip create --floating-ip-address 192.168.122.200 --description "OCP API" --project shiftstack public
openstack floating ip create --floating-ip-address 192.168.122.210 --description "OCP Ingress" --project shiftstack public

openstack security group create allow_ssh --project shiftstack
openstack security group rule create --protocol tcp --dst-port 22 --project shiftstack allow_ssh

openstack security group create allow_ping --project shiftstack
openstack security group rule create --protocol icmp --project shiftstack allow_ping
openstack security group rule create --protocol ipv6-icmp --project shiftstack allow_ping

# openstack image show centos9-stream || wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 && openstack image create --public --disk-format qcow2 --file CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 centos9-stream && rm -f CentOS-Stream-*

export OS_CLOUD=rhoso_shiftstack

openstack image create --disk-format raw --file ~/capo/ubuntu-2204-kube-v1.29.5.img ubuntu-2204-kube-v1.29.5
#openstack image create --disk-format raw --file ~/capo/ubuntu-2204-kube-v1.28.5.img ubuntu-2204-kube-v1.28.5
#openstack image create --disk-format raw --file ~/capo/cirros-0.6.1-x86_64-disk.img cirros-0.6.1-x86_64-disk

openstack keypair show emacchi || openstack keypair create --public-key ~/.ssh/id_rsa.pub emacchi

echo
echo "DONE..."
