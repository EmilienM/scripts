#!/bin/bash
TMP_DIR=$(mktemp -d)
cd $TMP_DIR
git clone https://github.com/bitwarden/clients
cd clients
latest_tag=$(gh release list | grep -m1 CLI | awk '{print $4}')
fileversion=$(echo $latest_tag | cut -c 6-)
wget https://github.com/bitwarden/clients/releases/download/$latest_tag/bw-linux-$fileversion.zip
unzip bw-linux-$fileversion.zip
mv bw ~/bin/bw
chmod +x ~/bin/bw
rm -rf $TMP_DIR
