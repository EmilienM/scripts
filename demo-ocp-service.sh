oc create namespace demo
oc create deployment demo --image=quay.io/kuryr/demo -n demo
oc scale deploy/demo --replicas=2 -n demo
oc expose deploy/demo --port=80 --target-port=8080 --type=LoadBalancer -n demo
svc_ip=$(oc get svc -n demo --no-headers  | awk '{print $4}')
while [[ $svc_ip == *"pending"* ]]; do
  svc_ip=$(oc get svc -n demo --no-headers  | awk '{print $4}')
  echo "Waiting for the service to be online"
  sleep 5
done
for i in {1..10}; do
  curl $svc_ip
done
#oc delete ns demo
