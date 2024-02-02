#!/bin/bash
set -e

tmp_dir=$(mktemp -d)

export OS_CLOUD=foch_openshift
export CLUSTER_NAME="dev"
export KUBERNETES_VERSION="v1.28.5"
export CAPO_DIRECTORY=~/go/src/github.com/kubernetes-sigs/cluster-api-provider-openstack
export CONTROL_PLANE_MACHINE_COUNT=3
export WORKER_MACHINE_COUNT=3

export OPENSTACK_SSH_KEY_NAME="emilien"
export OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR="m1.large"
export OPENSTACK_NODE_MACHINE_FLAVOR="m1.large"
export OPENSTACK_FAILURE_DOMAIN="nova"
export OPENSTACK_IMAGE_NAME="ubuntu-2204-kube-v1.28.5"
export OPENSTACK_EXTERNAL_NETWORK_NAME="hostonly"
export OPENSTACK_EXTERNAL_NETWORK_ID=$(openstack network list -f value -c ID -c Name | grep $OPENSTACK_EXTERNAL_NETWORK_NAME | awk '{print $1}')
export OPENSTACK_CLOUD=${OS_CLOUD}
export OPENSTACK_DNS_NAMESERVERS="1.1.1.1"

if ! command -v docker &> /dev/null
then
    echo "docker could not be found, installing podman-docker"
    sudo dnf install -y podman-docker
fi
if ! systemctl is-active --user --quiet podman.socket; then
  systemctl --user start podman.socket
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

#### Prepare environment files
source $CAPO_DIRECTORY/templates/env.rc ~/.config/openstack/clouds.yaml foch_openshift

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
