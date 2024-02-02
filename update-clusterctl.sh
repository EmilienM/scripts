#!/bin/bash

## create a tmp dir
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-linux-amd64 -o clusterctl
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
rm -rf $TMP_DIR
