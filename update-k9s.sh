#!/bin/bash

## create a tmp dir
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xvf k9s_Linux_amd64.tar.gz
mv k9s ~/bin/k9s
rm -rf $TMP_DIR
