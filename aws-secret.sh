#!/bin/bash
export KUBECONFIG=~/ocp/auth/kubeconfig
TMP_DIR=$(mktemp -d)
aws-saml.py --target-role 637423598313-route53admin

cat <<EOF > $TMP_DIR/aws-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-access-key
  namespace: hypershift
stringData:
    credentials: |-
$(cat ~/.aws/credentials | sed 's/^/      /')
EOF
sed -i 's/saml/default/g' $TMP_DIR/aws-credentials.yaml

kubectl apply -f $TMP_DIR/aws-credentials.yaml
