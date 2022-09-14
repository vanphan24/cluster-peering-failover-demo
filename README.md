# cluster-peering-failover-demo

This demo will showcase the ability to failover services between two Consul datacenters (dc1 and dc2) that have been connected via Cluster peering. 
We will deploy a counting app where a dashboard service will connect to the upstream counting service. Both services will reside on dc1.

We will have another instance of the counting service running on dc2. We will similate a failure of the counting service on dc1 by taking down the whole counting service deployment. 

We will then observe how the dashboard will failover to the counting service residing on dc2.

![alt text](https://github.com/vanphan24/cluster-peering-demo/blob/main/images/Screen%20Shot%202022-08-18%20at%2010.40.40%20AM.png "Cluster Peering Demo")

# Pre-reqs

1. You have two Kubernetes clusters available. In this demo example, we will use Azure Kubernetes Service (AKS) but it can be applied to other K8s clusters.

    Note: 
    - If using AKS, you can use the Kubenet CNI or the Azure CNI. The Consul control plane and data plane will use Load Balancers to communicate between Consul datacenters.
    - Since Load Balancers are used on both control plane and data plane, each datacenter can reside on different networks (VNETS, VPCs). No direct network connections (ie peering connections) are required. 
    
2. Add or update your hashicorp helm repo:

```
helm repo add hashicorp https://helm.releases.hashicorp.com
```
or
```
helm repo update hashicorp
```

  
# Deploy Consul on each Kubernetes cluster.
Note: In our example, we will name our Kubernetes clusters **dc1** and **dc2**.

1. Clone consul-k8s git repo
```
git clone https://github.com/hashicorp/consul-k8s.git
```

2. Nagivate to the **consul-k8s** folder. 

```
cd consul-k8s
```

3. Clone this repo
```
git clone https://github.com/vanphan24/cluster-peering-failover-demo.git
```

4. Nagivate to the **cluster-peering-failover-demo/countingapp** folder. 

```
cd cluster-peering-failover-demo/countingapp
```

5. Set context and deploy Consul on dc1

```
kubectl config use-context dc1
helm install dc1 ../../charts/consul --values consul-values.yaml                                  
```

6. Confirm Consul deployed sucessfully

```
kubectl get pods --context dc1
NAME                                               READY   STATUS    RESTARTS   AGE

dc1-consul-client-8wtl5                            1/1     Running   0          2m
dc1-consul-connect-injector-6694d44877-jvp4s       1/1     Running   0          2m
dc1-consul-connect-injector-6694d44877-t65vh       1/1     Running   0          2m
dc1-consul-controller-8548797965-rtq6d             1/1     Running   0          2m
dc1-consul-mesh-gateway-747c58b75c-s68n7           2/2     Running   0          2m
dc1-consul-server-0                                1/1     Running   0          2m
dc1-consul-webhook-cert-manager-669bb6d774-sb5lz   1/1     Running   0          2m
```

8. Deploy both dashboard and counting service on dc1
```
kubectl apply -f dashboard.yaml --context dc1
kubectl apply -f counting.yaml --context dc1
```

9. Using your browser, check the dashboard UI and confirm the number displayed is incrementing. Append port :9002 to the browser URL.  
   You can get the dashboard UI's EXTERNAL IP address with
```   
kubectl get service dashboard --context dc1
```


# Deploy Consul on dc2 


10. Set context and deploy Consul on dc2

```
kubectl config use-context dc2
helm install dc2 ../../charts/consul --values consul-values.yaml      
```

11. Deploy counting service on dc2. This will be the failover service instance.

```
kubectl apply -f counting.yaml --context dc2
```


# Create cluster peering connection

12. Create Peering Acceptor on dc1 using the provided acceptor-for-dc2.yaml file.
Note: This step will establish dc1 as the Acceptor.
```
kubectl apply -f  acceptor-on-dc1-for-dc2.yaml --context dc1
```

13. Notice this will create a CRD called peeringacceptors and a secret called peering-token-dc2.
```
kubectl get peeringacceptors --context dc1
NAME   SYNCED   LAST SYNCED   AGE
dc2    True     2m46s         2m47s
```
```
kubectl get secrets --context dc1
```

14. Copy peering-token-dc2 from dc1 to dc2.
```
kubectl get secret peering-token-dc2 --context dc1 -o yaml | kubectl apply --context dc2 -f -
```

15. Create Peering Dialer on dc2 using the provided dialer-dc2.yaml file.
Note: This step will establish dc2 as the Dialer and will connect Consul on dc2 to Consul on dc1 using the peering-token.
```
kubectl apply -f  dialer-dc2.yaml --context dc2
```

16. Export counting service from dc2 to dc1.

```
kubectl apply -f exportedsvc-counting.yaml --context dc2
```

17. Retrieve the Consul public IP address on dc1 and put into an environmental variable

```
 export CONSUL_PUB_IP=$(kubectl get service dc1-consul-expose-servers -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context dc1)
```

18. Apply service-resolver.json file using the HTTP API. This service-resolver.json file will tell Consul how to handle failovers if the counting service fails locally. The IP address used if 
```
curl --request PUT --data @service-resolver.json http://$CONSUL_PUB_IP:8500/v1/config
```

19. Delete the counting service on dc1
```
kubectl delete -f counting.yaml --context dc1
```

20. Observe the dashboard service on your browser. You should notice that the counter has restarted since the dashboard is connecting to different counting service instance.

21. Bring counting service on dc1 back up.
```
kubectl apply -f counting.yaml --context dc1
```


22. Observe the dashboard service on your browser. Notice the the dashboard URL shows the coutner has restarted again since it automatically fails back to the original service on dc1.



