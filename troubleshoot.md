# Troubleshooting Guide

This document contains commands and procedures used to debug and fix common issues in this infrastructure.

## 1. Observability (Metrics & Logs)

### Verifying Alloy (Collector)
Check if Alloy is successfully scraping logs and metrics without errors.
```bash
# Check Alloy logs for errors (e.g., connection refused, fsnotify)
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=100

# Grep for specific errors
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=100 | grep "error"
```

### Verifying Grafana Datasources
Check if Grafana has the correct connection URLs for Mimir and Loki.
```bash
# Exec into Grafana pod to inspect generated datasources config
export POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n monitoring $POD -c grafana -- cat /etc/grafana/provisioning/datasources/datasources.yaml

# Expected URLs:
# Mimir: http://mimir-gateway.mimir.svc.cluster.local:80/prometheus
# Loki:  http://loki-gateway.monitoring.svc.cluster.local:80
```

### Connectivity Checks
Verify internal DNS and service reachability from within the cluster.
```bash
# Launch a temporary debug pod
kubectl run -it --rm debug-curl --image=curlimages/curl --restart=Never -- sh

# Inside the pod:
curl -v http://mimir-gateway.mimir.svc.cluster.local:80/prometheus/api/v1/query?query=up
curl -v http://loki-gateway.monitoring.svc.cluster.local:80/loki/api/v1/labels
```

---

## 2. Node System Limits (fsnotify)

### "Too many open files" Error
Monitoring stacks require high inotify limits. If you see `failed to create fsnotify watcher`, check the node limits.

```bash
# Check limits on a node using a debug container
kubectl debug node/rke2-node-1 -it --image=busybox -- sh -c "sysctl fs.inotify"

# Expected Monitoring Limits:
# fs.inotify.max_user_watches = 524288
# fs.inotify.max_user_instances = 8192
```

**Fix:** A `sysctl-tuner` DaemonSet is deployed in `kube-system` to automatically apply these settings.

---

## 3. Storage & Deployments

### Fixing Stuck PVCs (Multi-Attach Error)
Hetzner Block Storage (CSI) is **ReadWriteOnce** (RWO) and does not support multi-attach. If a Deployment uses `RollingUpdate`, the new pod may get stuck waiting for the volume.

**Fix 1 (Permanent):** Set `deploymentStrategy: type: Recreate` in your Application values.

**Fix 2 (Immediate):** Force delete the OLD running pod to release the volume.
```bash
# Find the running pod preventing volume release
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Force delete it
kubectl delete pod -n monitoring <old-pod-name> --force --grace-period=0
```

---

## 4. ArgoCD & GitOps

### Force Refreshing Applications
If GitOps is synced but changes aren't reflecting (or ConfigMaps are stuck), force a hard refresh.

```bash
# Refresh a specific application
kubectl -n argocd patch application <app-name> --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Example: Refresh Grafana
kubectl -n argocd patch application grafana --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Checking Port Conflicts
Identify which process is using a specific port (e.g., 9100) on the host network.
```bash
# List all pods using hostNetwork and their listen addresses
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.hostNetwork == true) | .metadata.namespace + "/" + .metadata.name + " " + (.spec.containers[].args[]? // "")' | grep 9100
```

---

## 5. ArgoCD & GitOps Sync Issues (Advanced)

### Fixing "Progressing" / "OutOfSync" Status
If an app like Grafana or GitLab is stuck in "Progressing":

**1. Check the Resource Customizations (Health Checks)**
HostNetwork Ingresses often stay "Progressing" because they lack a LoadBalancer IP. We fixed this by adding a custom health check to `argocd-cm`.
```bash
# View current health checks
kubectl get configmap -n argocd argocd-cm -o jsonpath='{.data.resource\.customizations\.health\.networking\.k8s\.io_Ingress}'
```

**2. Manual ConfigMap Patching (When Sync Fails)**
If ArgoCD says "Synced" but the cluster state is old (e.g. `mimir-nginx` vs `mimir-gateway` URL), you might need to manually patch the resource to unblock things.
```bash
# Example: Manually fixing Grafana Datasources ConfigMap
kubectl get cm -n monitoring grafana -o json | sed 's/mimir-nginx/mimir-gateway/g' | kubectl apply -f -

# Then restart the deployment
kubectl rollout restart deployment -n monitoring grafana
```

**3. Restarting Services/Controllers**
Sometimes config changes aren't picked up until a restart.
```bash
# Restart Alloy (DaemonSet)
kubectl rollout restart ds -n monitoring alloy

# Restart ArgoCD Repo Server (if cache is stale)
kubectl rollout restart deployment -n argocd argocd-repo-server
```

**4. Force Deleting Stuck Resources**
If a namespace or resource won't delete (finalizers):
```bash
# Patch finalizers to empty
kubectl patch app <app-name> -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### GitOps Sync Workflow
When fixing config (e.g., incorrect Service URL):
1. **Fix in Git**: Commit the change to `apps/grafana.yaml`.
2. **Push**: `git push`
3. **Hard Refresh**: ArgoCD might cache the old commit.
   ```bash
   kubectl -n argocd patch application <app> --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```
4. **Verify Object**: check the actual object in K8s.
   ```bash
   kubectl get cm -n monitoring alloy -o yaml
   ```

---

## 6. General Debugging & Discovery

### Discovering Service Names
When internal DNS fails, check the actual service names.
```bash
# List services in a namespace
kubectl get svc -n mimir
kubectl get svc -n monitoring | grep loki
```

### Checking ArgoCD Application Status
View the sync and health status of all GitOps applications.
```bash
kubectl get applications -n argocd
```

### Diagnosing Pod Startup Issues
If a pod is stuck in `Pending` or `Init`, describe it to see events (e.g., MountVolume.SetUp failed).
```bash
kubectl describe pod -n monitoring <pod-name>
```

### Waiting for Pod Readiness
Wait for a pod to become ready during a script or manual rollout.
```bash
kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=grafana --timeout=120s
```


