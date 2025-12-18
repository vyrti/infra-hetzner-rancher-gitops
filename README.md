# GitOps - ArgoCD Application Definitions

Kubernetes platform deployed via ArgoCD App of Apps pattern.

## Quick Start

```bash
# 1. Deploy infrastructure
cd infrastructure && terraform init && terraform apply

# 2. Update repo URL in root.yaml and apps/cluster-issuer.yaml

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
| ArgoCD | https://argo.aleklab.com |
| Grafana | https://grafana.aleklab.com |
| Mimir | https://mimir.aleklab.com |
| Loki | https://loki.aleklab.com |
| Kubecost | https://kubecost.aleklab.com |
| Vault | https://vault.aleklab.com |
| GitLab | https://gitlab.aleklab.com |
