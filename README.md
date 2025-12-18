# GitOps - ArgoCD Application Definitions

Kubernetes platform deployed via ArgoCD App of Apps pattern.

## Quick Start

```bash
# 1. Deploy infrastructure
cd infrastructure && terraform init && terraform apply

# 2. Update repo URL in root.yaml

# 3. Apply root application
export KUBECONFIG=$(pwd)/rke2.yaml
kubectl apply -f ../gitops/root.yaml
```

## Applications (13 apps)

| App | Version | Namespace |
|-----|---------|-----------|
| **Mimir** | 6.0.5 | mimir |
| **Grafana** | 8.8.2 | monitoring |
| **Loki** | 6.24.0 | monitoring |
| **Tempo** | 1.14.0 | monitoring |
| **Alloy** | 0.12.0 | monitoring |
| **kube-state-metrics** | 5.27.0 | monitoring |
| **node-exporter** | 4.43.0 | monitoring |
| **Kubecost** | 2.6.1 | kubecost |
| **Trivy** | 0.31.0 | trivy-system |
| **Istio** | 1.24.2 | istio-system |
| **OpenBao** | 0.9.0 | openbao |
| **GitLab** | 9.6.1 | gitlab |

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Grafana                              │
│                    (Unified Dashboard)                       │
└───────────────────────────┬─────────────────────────────────┘
                            │ queries
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   ┌─────────┐         ┌─────────┐         ┌─────────┐
   │  Mimir  │         │  Loki   │         │  Tempo  │
   │(Metrics)│         │ (Logs)  │         │(Traces) │
   └────┬────┘         └────┬────┘         └────┬────┘
        │                   │                   │
        └───────────────────┴───────────────────┘
                            ▲
                    ┌───────┴───────┐
                    │     Alloy     │
                    │  (Collector)  │
                    └───────┬───────┘
                            │ scrapes
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│kube-state-    │   │ node-exporter │   │   Kubelet/    │
│   metrics     │   │               │   │   cAdvisor    │
└───────────────┘   └───────────────┘   └───────────────┘
```

## Access URLs

| Service | URL |
|---------|-----|
| Rancher | https://kube.aleklab.com |
| ArgoCD | https://argo.aleklab.com |
| Grafana | https://grafana.aleklab.com |
| Mimir | https://mimir.aleklab.com |
| Loki | https://loki.aleklab.com |
| Kubecost | https://kubecost.aleklab.com |
| Vault (OpenBao) | https://vault.aleklab.com |
| GitLab | https://gitlab.aleklab.com |

## Credentials

> **Note**: Make sure `KUBECONFIG` is set: `export KUBECONFIG=./infrastructure/rke2.yaml`

### Rancher
```bash
# Username: admin
# Get bootstrap password (first login only)
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

### ArgoCD
```bash
# Username: admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### Grafana
```bash
# Username: admin
kubectl -n monitoring get secret grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

### GitLab
```bash
# Username: root
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d && echo
```

### OpenBao (Vault)
```bash
# Get root token and unseal keys
kubectl -n openbao exec openbao-0 -- cat /vault/data/init.json 2>/dev/null || \
  echo "OpenBao not initialized. Initialize with: kubectl -n openbao exec -it openbao-0 -- bao operator init"
```

### Kubecost
```bash
# No authentication by default (open access)
# To enable auth, configure in helm values
```

### Mimir / Loki / Tempo
```bash
# No authentication by default (internal services)
# Accessed through Grafana data sources
```
