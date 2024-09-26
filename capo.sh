#!/bin/bash
set -e

tmp_dir=$(mktemp -d)

export OS_CLOUD=beaker_openshift
export CLUSTER_NAME="dev-test"
export KUBERNETES_VERSION="v1.28.5"
export CAPO_DIRECTORY=~/go/src/github.com/kubernetes-sigs/cluster-api-provider-openstack
export CLUSTER_TOPOLOGY=true
export CONTROL_PLANE_MACHINE_COUNT=3
export WORKER_MACHINE_COUNT=3

export OPENSTACK_SSH_KEY_NAME="emacchi"
export OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR="m1.large"
export OPENSTACK_NODE_MACHINE_FLAVOR="m1.large"
export OPENSTACK_FAILURE_DOMAIN="nova"
export OPENSTACK_IMAGE_NAME="ubuntu-2204-kube-v1.28.5"
export OPENSTACK_EXTERNAL_NETWORK_NAME="hostonly"
export OPENSTACK_EXTERNAL_NETWORK_ID=$(openstack network show -f value -c id $OPENSTACK_EXTERNAL_NETWORK_NAME | awk '{print $1}')
export OPENSTACK_CLOUD=${OS_CLOUD}
export OPENSTACK_DNS_NAMESERVERS="1.1.1.1"

export OPENSTACK_CLOUD_PROVIDER_CONF_B64=$(cat ~/capo/cloud.conf|envsubst|base64 -w0)

#### Prepare environment files
source $CAPO_DIRECTORY/templates/env.rc ~/.config/openstack/clouds.yaml ${OS_CLOUD}

if ! command -v docker &> /dev/null
then
    echo "docker could not be found, installing podman-docker"
    sudo dnf install -y podman-docker
fi
if ! systemctl is-active --user --quiet podman.socket; then
  systemctl --user start podman.socket
fi

if ! command -v yq &> /dev/null
then
    echo "yq could not be found, installing it"
    sudo dnf install -y yq
fi

if ! command -v helm &> /dev/null
then
    echo "helm could not be found, installing it"
    sudo dnf install -y helm
fi

for cmd in ctlptl kind envsubst clusterctl kubectl kustomize; do
  if ! command -v $cmd &> /dev/null
  then
      echo "$cmd could not be found, please install it"
      exit
  fi
done

if ! grep -q "localhost:5000" /etc/containers/registries.conf; then
  echo "ERROR: /etc/containers/registries.conf doesn't consider localhost:5000 as insecure, please add it"
  exit
fi

ctlptl delete cluster kind-kind || true
ctlptl delete registry ctlptl-registry || true

ctlptl create registry ctlptl-registry --port=5000
ctlptl create cluster kind --registry=ctlptl-registry

# Create secret for clouds.yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  cacert: ${OPENSTACK_CLOUD_CACERT_B64}
  clouds.yaml: ${OPENSTACK_CLOUD_YAML_B64}
kind: Secret
metadata:
  labels:
    clusterctl.cluster.x-k8s.io/move: "true"
  name: ${CLUSTER_NAME}-cloud-config
EOF

sed -i '/OPENSTACK_EXTERNAL_NETWORK_ID/d' ~/go/src/github.com/kubernetes-sigs/cluster-api/tilt-settings.yaml
sed -i '/OPENSTACK_CLOUD_CACERT_B64/d' ~/go/src/github.com/kubernetes-sigs/cluster-api/tilt-settings.yaml
sed -i '/OPENSTACK_CLOUD_YAML_B64/d' ~/go/src/github.com/kubernetes-sigs/cluster-api/tilt-settings.yaml
cat <<EOF >> ~/go/src/github.com/kubernetes-sigs/cluster-api/tilt-settings.yaml
  OPENSTACK_EXTERNAL_NETWORK_ID: "${OPENSTACK_EXTERNAL_NETWORK_ID}"
  OPENSTACK_CLOUD_CACERT_B64: "${OPENSTACK_CLOUD_CACERT_B64}"
  OPENSTACK_CLOUD_YAML_B64: "${OPENSTACK_CLOUD_YAML_B64}"
EOF

if [ -z "$DEMO" ]; then
  exit
fi

read -p "Press Enter to continue" </dev/tty
clear
echo "clusterctl init --infrastructure openstack"
clusterctl init --infrastructure openstack

echo "clusterctl generate cluster $CLUSTER_NAME > ~/capo/demo.yaml"
read -p "Press Enter to continue" </dev/tty

echo "kubectl apply -f ~/capo/demo.yaml"
kubecolor apply -f ~/capo/demo.yaml
read -p "Press Enter to continue" </dev/tty

clear

echo "clusterctl get kubeconfig dev-test > ~/capo/kube.config"
clusterctl get kubeconfig dev-test > ~/capo/kube.config

echo "curl -L https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml | kubectl --kubeconfig ~/capo/kube.config apply -f -"
curl -L https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml | kubectl --kubeconfig ~/capo/kube.config apply -f -
read -p "Press Enter to continue" </dev/tty

echo "kubectl get kubeadmcontrolplane"
kubecolor get kubeadmcontrolplane
sleep 5

echo "kubectl --kubeconfig ~/capo/kube.config -n kube-system create secret generic cloud-config --from-file ~/capo/cloud.conf"
kubecolor --kubeconfig ~/capo/kube.config -n kube-system create secret generic cloud-config --from-file ~/capo/cloud.conf

echo "kubectl apply --kubeconfig ~/capo/kube.config -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-roles.yaml"
kubecolor apply --kubeconfig ~/capo/kube.config -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-roles.yaml
echo "kubectl apply --kubeconfig ~/capo/kube.config -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-role-bindings.yaml"
kubecolor apply --kubeconfig ~/capo/kube.config -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-role-bindings.yaml
echo "kubectl apply --kubeconfig ~/capo/kube.config -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml"
kubecolor apply --kubeconfig ~/capo/kube.config -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml
sleep 10

clear

echo "clusterctl describe cluster dev-test"
clusterctl describe cluster dev-test
echo
echo "The end"
