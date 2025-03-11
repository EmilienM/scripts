#!/bin/bash
set -e

tmp_dir=$(mktemp -d)

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
