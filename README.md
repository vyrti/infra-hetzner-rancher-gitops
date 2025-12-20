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

## Applications (30 apps)

| App | Version | Namespace |
|-----|---------|-----------|
| **Mimir** | 6.0.5 | mimir |
| **Grafana** | 10.3.2 | monitoring |
| **Loki** | 6.49.0 | monitoring |
| **Tempo** | 1.24.1 | monitoring |
| **Alloy** | 1.5.1 | monitoring |
| **kube-state-metrics** | 7.0.0 | monitoring |
| **node-exporter** | 4.49.2 | monitoring |
| **Kubecost** | 2.5.5 | kubecost |
| **Trivy** | 0.20.1 | trivy-system |
| **Istio** | 1.24.2 | istio-system |
| **OpenBao** | 0.21.2 | openbao |
| **GitLab** | 9.6.2 | gitlab |
| **Velero** | 11.2.0 | velero |
| **Argo Workflows** | 0.46.2 | argo |
| **MLflow** | 1.8.1 | mlflow |
| **hcloud-csi** | 2.18.3 | kube-system |
| **hcloud-ccm** | 1.27.0 | kube-system |
| **sysctl-tuner** | HEAD | kube-system |
| **Kyverno** | 3.6.1 | kyverno |
| **CloudNativePG** | 0.27.0 | cnpg-system |
| **ExternalDNS** | 1.19.0 | external-dns |
| **Falco** | 7.0.2 | falco |
| **KEDA** | 2.18.2 | keda |
| **VPA** | 4.10.1 | vpa |
| **External Secrets** | 0.20.4 | external-secrets |
| **Crossplane** | 2.1.3 | crossplane-system |
| **Cert-Manager** | v1.19.1 | cert-manager |
| **Traefik** | latest | traefik |
| **Rancher** | latest | cattle-system |
| **ArgoCD** | stable | argocd |

> [!IMPORTANT]
> **ExternalDNS** requires a Cloudflare API token secret. Create it before deploying:

```bash
kubectl create namespace external-dns
kubectl create secret generic cloudflare-api-token \
  --namespace external-dns \
  --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN
```

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
| Argo Workflows | https://workflows.aleklab.com |
| MLflow | https://mlflow.aleklab.com |

## Credentials

> **Note**: Make sure `KUBECONFIG` is set: `export KUBECONFIG=./infrastructure/rke2.yaml`

### Rancher
```bash
# Username: admin
# Get bootstrap password (first login only)
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\\n"}}'
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

### MLflow
```bash
# Tracking Server: Open access
# Artifact Storage (MinIO): Uses generic 'minio' credentials from Velero instance
# User: minio
# Pass: minio123
# PostgreSQL:
# User: mlflow
# Pass: mlflow123
```

### Argo Workflows
```bash
# Server authentication enabled
# Get token (if using client auth) or check specific auth mode details in values
```

## Observability Guide

### 📊 Viewing Dashboards
1. Login to **Grafana** (https://grafana.aleklab.com)
2. Go to **Dashboards** > **Browse**. You will see dashboards for:
   - **Cluster**: Kubernetes Cluster, Nodes, Pods
   - **Network**: Traefik (Ingress), Istio Mesh & Services
   - **Apps**: ArgoCD, GitLab, Cert-Manager
   - **Data**: PostgreSQL, Redis, MinIO
   - **Observability**: Mimir Overview, Logs (Loki)


### 🔍 Viewing Logs (Loki)
1. Go to **Explore** (Compass icon on the left)
2. Select **Loki** as the datasource at the top-left.
3. Use the **Label Browser** or enter a LogQL query:
   - **View logs for a specific pod**: `{pod="<pod-name>"}`
   - **View logs for a namespace**: `{namespace="<namespace>"}`
   - **Search for errors**: `{namespace="gitlab"} |= "error"`
4. Click **Run Query** (top right) to see the live stream.

### 📉 Distributed Tracing (Tempo)
1. Go to **Explore**
2. Select **Tempo** as the datasource.
3. Select **Query Type** > **Search** to find traces or specific Trace IDs.

---

## 💾 Velero Backup & Restore Guide

Velero provides backup and disaster recovery for Kubernetes resources and persistent volumes.

### Automated Backup Schedules

| Schedule | Time | Retention | Namespaces |
|----------|------|-----------|------------|
| **Daily** | 3:00 AM | 7 days | gitlab, openbao, monitoring, kubecost |
| **Weekly Full** | Sunday 4:00 AM | 30 days | All (except kube-system) |

### Install Velero CLI

```bash
# macOS
brew install velero

# Linux
wget https://github.com/vmware-tanzu/velero/releases/download/v1.16.0/velero-v1.16.0-linux-amd64.tar.gz
tar -xvf velero-v1.16.0-linux-amd64.tar.gz
sudo mv velero-v1.16.0-linux-amd64/velero /usr/local/bin/
```

### Common Velero Commands

```bash
# View all backups
velero backup get

# View backup details
velero backup describe <backup-name> --details

# View scheduled backups
velero schedule get

# View backup logs
velero backup logs <backup-name>
```

### Create Manual Backup

```bash
# Backup a specific namespace
velero backup create gitlab-backup --include-namespaces gitlab --wait

# Backup multiple namespaces
velero backup create full-backup --include-namespaces gitlab,openbao,monitoring

# Backup with specific resources only
velero backup create secrets-backup --include-resources secrets --include-namespaces gitlab

# Backup entire cluster (excluding system namespaces)
velero backup create cluster-backup --exclude-namespaces kube-system,kube-public
```

### Restore from Backup

```bash
# List available backups
velero backup get

# Restore entire backup to original namespaces
velero restore create --from-backup <backup-name>

# Restore to a different namespace (useful for testing)
velero restore create --from-backup gitlab-backup --namespace-mappings gitlab:gitlab-restore

# Restore specific resources only
velero restore create --from-backup <backup-name> --include-resources deployments,configmaps

# Check restore status
velero restore get
velero restore describe <restore-name>
```

### Disaster Recovery Scenarios

#### Scenario 1: Recover a deleted namespace
```bash
# 1. Find the most recent backup containing the namespace
velero backup get

# 2. Restore it
velero restore create --from-backup daily-backup-<timestamp> --include-namespaces gitlab
```

#### Scenario 2: Migrate to a new cluster
```bash
# On OLD cluster: Create a final backup
velero backup create migration-backup --exclude-namespaces kube-system

# On NEW cluster: Install Velero with same storage config, then restore
velero restore create --from-backup migration-backup
```

#### Scenario 3: Rollback after failed upgrade
```bash
# 1. Before upgrade, create a backup
velero backup create pre-upgrade-gitlab --include-namespaces gitlab

# 2. If upgrade fails, delete the namespace and restore
kubectl delete namespace gitlab
velero restore create --from-backup pre-upgrade-gitlab
```

### Troubleshooting

```bash
# Check Velero pod status
kubectl get pods -n velero

# View Velero logs
kubectl logs -n velero deployment/velero

# Check backup storage location status
velero backup-location get

# Verify MinIO storage is accessible
kubectl exec -n velero deployment/velero -- velero backup-location get
```
