#!/bin/bash
TMP_DIR=$(mktemp -d)
cd $TMP_DIR
git clone https://github.com/tilt-dev/tilt
cd tilt
latest_tag=$(gh release list | grep -m1 Latest | awk '{print $3}')
fileversion=$(echo $latest_tag | cut -c 2-)
wget https://github.com/tilt-dev/tilt/releases/download/$latest_tag/tilt.$fileversion.linux.x86_64.tar.gz
tar xf tilt.$fileversion.linux.x86_64.tar.gz
sudo mv tilt /usr/local/bin
chmod +x /usr/local/bin/tilt
rm -rf $TMP_DIR
