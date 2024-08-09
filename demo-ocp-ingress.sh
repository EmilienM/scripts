export KUBECONFIG=/tmp/openstack.kubeconfig
oc new-project hello-openshift
oc create -f demo-ingress.yaml
oc expose pod/hello-openshift
oc expose svc hello-openshift
sleep 5
echo
echo
echo "curl http://hello-openshift-hello-openshift.apps.emacchi-hcp.shiftstack-dev.devcluster.openshift.com"
curl http://hello-openshift-hello-openshift.apps.emacchi-hcp.shiftstack-dev.devcluster.openshift.com/
echo
echo "Deleting..."
oc delete ns/hello-openshift
