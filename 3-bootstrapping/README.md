# Bootstrap


kubectl patch daemonset aws-node -n kube-system -p '{"spec":{"template":{"spec":{"nodeSelector":{"no-such-node": "true"}}}}}'
kubectl patch daemonset kube-proxy -n kube-system -p '{"spec":{"template":{"spec":{"nodeSelector":{"no-such-node": "true"}}}}}'
kubectl scale deployment coredns --replicas=0 -n kube-system


kubectl scale deployment coredns --replicas=1 -n kube-system
kubectl -n kube-system rollout restart deployment/cilium-operator

kubectl -n kube-system rollout restart ds/cilium

The bootstrap step configures a minimal set of resources needed for the cluster to be useable. This includes:



https://gitea.com/gitea/helm-gitea


- The EKS `aws-auth` configmap which configures cluster access
- Karpenter and default resources so that nodes can be spun up for controllers
- Crossplane to enable controllers to be installed and have AWS permissions
- FluxCD to install resources

As of this time, neither crossplane nor FluxCD are actually in use, but the infrastructure is present to use them
in the future.


## Cilium Taint Manager
The cluster includes a CronJob that automatically manages Cilium taints during rollouts. This helps prevent pods from getting stuck during Cilium DaemonSet upgrades due to the `node.cilium.io/agent-not-ready` taint. This cron is applied automatically in `resources/3-bootstrapping/_cilium.tf` and is feature gated with the `use_cilium_helper_cron`

### Features

- Runs every 5 minutes to check for stuck Cilium pods
- Automatically removes taints from nodes where Cilium pods have been stuck for more than 5 minutes
- Handles NodeAffinity issues where pods can't be scheduled at all
- Detects and resolves scheduling failures due to taints
- Only operates during active Cilium rollouts
- Prevents concurrent job executions
- Includes proper RBAC permissions

### Deployment

```sh
# Deploy the Cilium taint manager CronJob
kubectl apply -f 3-bootstrapping/cilium-manifests/cilium-taint-manager-cronjob.yaml
```

### Management Commands

```sh
# Check CronJob status
kubectl get cronjob cilium-taint-manager -n kube-system

# List recent jobs
kubectl get jobs -n kube-system | grep cilium-taint-manager

# Check logs of a specific job
kubectl logs -n kube-system job/cilium-taint-manager-<timestamp>

# Trigger a manual run
kubectl create job --from=cronjob/cilium-taint-manager cilium-taint-manager-manual -n kube-system

# Suspend the CronJob
kubectl patch cronjob cilium-taint-manager -n kube-system -p '{"spec": {"suspend": true}}'

# Resume the CronJob
kubectl patch cronjob cilium-taint-manager -n kube-system -p '{"spec": {"suspend": false}}'
```

### Cleanup

```sh
# Remove the CronJob and associated resources
kubectl delete cronjob cilium-taint-manager -n kube-system
kubectl delete clusterrolebinding cilium-taint-manager
kubectl delete clusterrole cilium-taint-manager
kubectl delete serviceaccount cilium-taint-manager -n kube-system
```

## Known Issues
- If using `bottlerocket` AMIs and set `nodeinit.enabled: false` in `/3-bootstrapping/values/cilium.yaml` [Reference](https://github.com/cilium/cilium/issues/19256 )
- Using cilium seems to brick the instance metadata discovery functions, but [irsa](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) still works.
- Newer versions of cilium seem to break eks rounting? https://github.com/cilium/cilium/issues/38100 
- https://github.com/bottlerocket-os/bottlerocket/issues/1405#issuecomment-804196007

# Patch the deployment to add AWS_REGION
kubectl -n kube-system patch deployment cilium-operator -p '{"spec":{"template":{"spec":{"containers":[{"name":"cilium-operator","env":[{"name":"AWS_REGION","value":"us-east-2"}]}]}}}}'

# Or edit the deployment directly
kubectl -n kube-system edit deployment cilium-operator
### References
- [text](url)
- [cilium](https://cilium.io/)
  - [cilium-requrements](https://docs.cilium.io/en/stable/network/kubernetes/requirements/)
  - [cilium-eks-install](https://docs.cilium.io/en/stable/installation/k8s-install-helm/)
  - [cilium-taints](https://docs.cilium.io/en/stable/installation/taints/#taint-effects)
  - [cilium-eni](https://docs.cilium.io/en/stable/network/concepts/ipam/eni/)
- [aws-load-balancer-controller](https://kubernetes-sigs.github.io//v2.8/how-it-works/#ip-mode)
- [gateway-api](https://gateway-api.sigs.k8s.io/implementations/?h=eks#amazon-elastic-kubernetes-service)
  - [aws-lattice](https://aws.amazon.com/vpc/lattice/pricing/)