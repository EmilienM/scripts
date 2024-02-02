#!/bin/bash
TMP_DIR=$(mktemp -d)
cd $TMP_DIR
git clone https://github.com/kubernetes-sigs/kustomize
cd kustomize
latest_tag=$(gh release list | grep -m1 kustomize | awk '{print $3}')
fileversion=$(echo $latest_tag | cut -c 11-)
rm -rf kustomize
wget https://github.com/kubernetes-sigs/kustomize/releases/download/$latest_tag/kustomize_${fileversion}_linux_amd64.tar.gz
tar xf kustomize_${fileversion}_linux_amd64.tar.gz
sudo mv kustomize /usr/local/bin/kustomize
chmod +x /usr/local/bin/kustomize
rm -rf $TMP_DIR
