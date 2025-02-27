#!/bin/bash

trap "rm -rf $TMP_DIR" EXIT

TMP_DIR=$(mktemp -d)
echo "TMP_DIR: $TMP_DIR"
cd $TMP_DIR
mkdir out

function install_oc_install {
	mkdir oc_install && cd oc_install
	wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-install-linux.tar.gz
	tar xf openshift-install-linux.tar.gz
	mv openshift-install ../out/openshift-install-latest
	cd .. && rm -rf oc_install
}

function install_oc_client {
	mkdir oc && cd oc
	wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz
	tar xf openshift-client-linux.tar.gz
	mv oc ../out
	cd .. && rm -rf oc
}

function install_bw {
	git clone https://github.com/bitwarden/clients && cd clients
	latest_tag=$(gh release list | grep -m1 CLI | awk '{print $3}')
	fileversion=$(echo $latest_tag | cut -c 6-)
	wget https://github.com/bitwarden/clients/releases/download/$latest_tag/bw-linux-$fileversion.zip
	unzip bw-linux-$fileversion.zip
	mv bw ../out
	cd .. && rm -rf clients
}

function install_clusterctl {
	curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-linux-amd64 -o out/clusterctl
}

function install_k9s {
	sudo dnf5 install -y https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.rpm
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

function install_rclone {
	git clone https://github.com/rclone/rclone && cd rclone
	latest_tag=$(gh release list | grep -m1 Latest | awk '{print $2}')
	sudo dnf5 install -y https://github.com/rclone/rclone/releases/download/$latest_tag/rclone-$latest_tag-linux-amd64.rpm
	cd .. && rm -rf rclone
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

function install_kor {
	git clone https://github.com/yonahd/kor && cd kor
	latest_tag=$(gh release list | grep -m1 Latest | awk '{print $3}')
	wget https://github.com/yonahd/kor/releases/download/$latest_tag/kor_Linux_x86_64.tar.gz
	tar xf kor_Linux_x86_64.tar.gz 
	mv kor ../out
	cd .. && rm -rf kor
}

function install_hwatch {
	sudo dnf5 install -y cargo
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

function install_gh_extensions {
	sudo dnf5 install -y dnf5-plugins
	sudo dnf5 config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
	sudo dnf5 install -y gh --repo gh-cli
	gh extension install github/gh-copilot || true
	gh extension upgrade gh-copilot
}

function install_hcp {
	podman run --rm --privileged -it -v \
	  $PWD:/output docker.io/library/golang:1.23 /bin/bash -c \
	  'git clone https://github.com/openshift/hypershift.git && \
	  cd hypershift/ && \
	  make hypershift product-cli && \
	  mv bin/hypershift /output/hypershift && \
	  mv bin/hcp /output/hcp'
	mv hcp hypershift out
}

install_hcp
install_oc_client
install_oc_install
install_bw
install_clusterctl
install_k9s
install_kustomize
install_tilt
install_rclone
install_hwatch
install_kind
install_envsubst
install_ctlptl
install_kubecolor
install_kor
install_gh_extensions

chmod +x $TMP_DIR/out/*
cp $TMP_DIR/out/* ~/.local/bin
