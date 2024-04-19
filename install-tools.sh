#!/bin/bash

trap "rm -rf $TMP_DIR" EXIT

TMP_DIR=$(mktemp -d)
cd $TMP_DIR
mkdir out

function install_bw {
	git clone https://github.com/bitwarden/clients && cd clients
	latest_tag=$(gh release list | grep -m1 CLI | awk '{print $4}')
	fileversion=$(echo $latest_tag | cut -c 6-)
	wget https://github.com/bitwarden/clients/releases/download/$latest_tag/bw-linux-$fileversion.zip
	unzip bw-linux-$fileversion.zip
	mv bw ../out
	cd .. && rm -rf clients
}

function install_clusterctl {
	curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-linux-amd64 -o bin/clusterctl
}

function install_k9s {
	mkdir k9s && cd k9s
	wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
	tar -xvf k9s_Linux_amd64.tar.gz
	mv k9s ../out
	cd .. && rm -rf k9s
}

function install_kustomize {
	git clone https://github.com/kubernetes-sigs/kustomize && cd kustomize
	latest_tag=$(gh release list | grep -m1 kustomize | awk '{print $3}')
	fileversion=$(echo $latest_tag | cut -c 11-)
	rm -rf kustomize
	wget https://github.com/kubernetes-sigs/kustomize/releases/download/$latest_tag/kustomize_${fileversion}_linux_amd64.tar.gz
	tar xf kustomize_${fileversion}_linux_amd64.tar.gz
	mv kustomize ../out
	cd .. && rm -rf kustomize
}

function install_tilt {
	git clone https://github.com/tilt-dev/tilt && cd tilt
	latest_tag=$(gh release list | grep -m1 Latest | awk '{print $3}')
	fileversion=$(echo $latest_tag | cut -c 2-)
	wget https://github.com/tilt-dev/tilt/releases/download/$latest_tag/tilt.$fileversion.linux.x86_64.tar.gz
	tar xf tilt.$fileversion.linux.x86_64.tar.gz
	mv tilt ../out
	cd .. && rm -rf tilt
}

function install_kubecolor {
	git clone https://github.com/kubecolor/kubecolor && cd kubecolor
	latest_tag=$(gh release list | grep -m1 Latest | awk '{print $3}')
	fileversion=$(echo $latest_tag | cut -c 2-)
	wget https://github.com/kubecolor/kubecolor/releases/download/$latest_tag/kubecolor_${fileversion}_linux_amd64.tar.gz
	tar xf kubecolor_${fileversion}_linux_amd64.tar.gz
	mv kubecolor ../out
	cd .. && rm -rf kubecolor
}

function install_hwatch {
	cargo install hwatch
}

function install_kind {
	go install sigs.k8s.io/kind@latest
}

function install_envsubst {
	go install github.com/drone/envsubst@latest
}

function install_ctlptl {
	go install github.com/tilt-dev/ctlptl/cmd/ctlptl@latest
}

install_bw
install_clusterctl
install_k9s
install_kustomize
install_tilt
install_hwatch
install_kind
install_envsubst
install_ctlptl
install_kubecolor

chmod +x $TMP_DIR/out/*
cp $TMP_DIR/out/* ~/.local/bin
