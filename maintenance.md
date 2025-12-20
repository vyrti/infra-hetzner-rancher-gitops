# Hetzner-Rancher Infrastructure Maintenance Manual

> **Complete DevOps Operations Guide**
> Version 1.0 | Last Updated: December 2024

This comprehensive manual covers the complete management, maintenance, and operations of the Hetzner-Rancher Kubernetes infrastructure stack. It includes procedures for updating all applications, provisioning new clusters, disaster recovery, troubleshooting, and day-to-day operations.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites & Environment Setup](#2-prerequisites--environment-setup)
3. [Cluster Access & Authentication](#3-cluster-access--authentication)
4. [Infrastructure Management (Terraform)](#4-infrastructure-management-terraform)
5. [GitOps & ArgoCD Operations](#5-gitops--argocd-operations)
6. [Application Updates - Complete Guide](#6-application-updates---complete-guide)
7. [Rancher Management](#7-rancher-management)
8. [Provisioning New Clusters](#8-provisioning-new-clusters)
9. [Adding Clusters to Rancher (Terraform)](#9-adding-clusters-to-rancher-terraform)
10. [Adding Clusters to Rancher (Crossplane)](#10-adding-clusters-to-rancher-crossplane)
11. [Monitoring Stack Operations](#11-monitoring-stack-operations)
12. [Security Stack Operations](#12-security-stack-operations)
13. [Backup & Disaster Recovery](#13-backup--disaster-recovery)
14. [Secrets Management](#14-secrets-management)
15. [Service Mesh (Istio) Operations](#15-service-mesh-istio-operations)
16. [CI/CD Platform Operations](#16-cicd-platform-operations)
17. [Autoscaling Operations](#17-autoscaling-operations)
18. [Storage Management](#18-storage-management)
19. [Network & DNS Management](#19-network--dns-management)
20. [Troubleshooting Guide](#20-troubleshooting-guide)
21. [Runbooks & Emergency Procedures](#21-runbooks--emergency-procedures)
22. [Best Practices & Standards](#22-best-practices--standards)

---

## 1. Architecture Overview

### 1.1 Infrastructure Stack Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HETZNER CLOUD                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                      │
│  │ rke2-node-1 │  │ rke2-node-2 │  │ rke2-node-3 │  (cx43 servers)      │
│  │  (Server)   │  │  (Server)   │  │  (Server)   │                      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                      │
│         │                │                │                              │
│         └────────────────┼────────────────┘                              │
│                          │                                               │
│              ┌───────────┴───────────┐                                   │
│              │   Hetzner Load Balancer │                                 │
│              │     (LB11 - TCP)         │                                │
│              │   Ports: 80, 443, 6443   │                                │
│              └───────────┬───────────┘                                   │
└──────────────────────────┼──────────────────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │  Cloudflare  │
                    │     DNS      │
                    └─────────────┘
```

### 1.2 Kubernetes Distribution

| Component | Version | Description |
|-----------|---------|-------------|
| RKE2 | Latest | Rancher Kubernetes Engine 2 |
| Control Plane | 3 nodes | High availability server mode |
| CNI | Canal | Default RKE2 networking |
| Ingress | Traefik | DaemonSet with hostNetwork |

### 1.3 Application Stack (30 Applications)

| Category | Applications |
|----------|--------------|
| **Platform** | Rancher, ArgoCD, Crossplane |
| **Monitoring** | Mimir, Loki, Tempo, Grafana, Alloy, kube-state-metrics, node-exporter |
| **Security** | Kyverno, Trivy, Falco, OpenBao |
| **CI/CD** | GitLab, Argo Workflows |
| **Networking** | Traefik, Istio, ExternalDNS |
| **Storage** | hcloud-csi, Velero |
| **Autoscaling** | KEDA, VPA |
| **Secrets** | External Secrets, OpenBao |
| **ML/Data** | MLflow |
| **Cost** | Kubecost |

### 1.4 Network Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────┐
│     Hetzner Load Balancer       │
│  Public IP: <LB_IP>             │
│  - :80  → nodes:80  (HTTP)      │
│  - :443 → nodes:443 (HTTPS)     │
│  - :6443 → nodes:6443 (K8s API) │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│   Traefik (DaemonSet)           │
│   hostNetwork: true             │
│   - HTTP → HTTPS redirect       │
│   - TLS termination             │
│   - IngressRoute routing        │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│   Kubernetes Services           │
│   - ClusterIP services          │
│   - Internal DNS resolution     │
└─────────────────────────────────┘
```

---

## 2. Prerequisites & Environment Setup

### 2.1 Required Tools

```bash
# Install all required tools

# Kubernetes CLI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
brew install terraform
# OR
wget https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip
unzip terraform_1.9.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# ArgoCD CLI
brew install argocd
# OR
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/

# Velero CLI
brew install velero
# OR
wget https://github.com/vmware-tanzu/velero/releases/download/v1.17.1/velero-v1.17.1-linux-amd64.tar.gz
tar -xvf velero-v1.17.1-linux-amd64.tar.gz
sudo mv velero-v1.17.1-linux-amd64/velero /usr/local/bin/

# Hetzner Cloud CLI
brew install hcloud
# OR
wget https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
tar -xvf hcloud-linux-amd64.tar.gz && sudo mv hcloud /usr/local/bin/

# jq for JSON processing
brew install jq
# OR
sudo apt-get install jq

# yq for YAML processing
brew install yq
# OR
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod +x yq_linux_amd64 && sudo mv yq_linux_amd64 /usr/local/bin/yq
```

### 2.2 Environment Variables

Create a `.envrc` file (use direnv) or export manually:

```bash
# Required API Tokens (SENSITIVE - never commit!)
export HCLOUD_TOKEN="your-hetzner-api-token"
export CLOUDFLARE_API_TOKEN="your-cloudflare-api-token"

# Kubeconfig path
export KUBECONFIG="${PWD}/infrastructure/rke2.yaml"

# Optional: ArgoCD server
export ARGOCD_SERVER="argo.aleklab.com"

# Hetzner CLI context
hcloud context create hetzner-rancher
hcloud context use hetzner-rancher
```

### 2.3 Directory Structure

```
hetzner-rancher/
├── infrastructure/           # Terraform IaC
│   ├── main.tf              # Main infrastructure definition
│   ├── variables.tf         # Variable definitions
│   ├── terraform.tfvars     # Variable values (gitignored)
│   ├── cloud-init.yaml      # Server bootstrap script
│   ├── rke2.yaml            # Kubeconfig (gitignored)
│   └── modules/
│       └── argocd/          # ArgoCD Helm module
├── gitops/                  # ArgoCD GitOps repo
│   ├── root.yaml            # Root Application (App of Apps)
│   ├── apps/                # Application definitions
│   │   ├── grafana.yaml
│   │   ├── mimir.yaml
│   │   ├── loki.yaml
│   │   └── ... (27 apps)
│   ├── dashboards/          # Grafana dashboard ConfigMaps
│   ├── README.md            # Quick reference
│   └── troubleshoot.md      # Troubleshooting guide
└── maintenance.md           # This file
```

---

## 3. Cluster Access & Authentication

### 3.1 Kubeconfig Setup

```bash
# Set kubeconfig from infrastructure directory
export KUBECONFIG=$(pwd)/infrastructure/rke2.yaml

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES                       AGE   VERSION
# rke2-node-1   Ready    control-plane,etcd,master   Xd    v1.30.x+rke2r1
# rke2-node-2   Ready    control-plane,etcd,master   Xd    v1.30.x+rke2r1
# rke2-node-3   Ready    control-plane,etcd,master   Xd    v1.30.x+rke2r1
```

### 3.2 Application Credentials

#### Rancher
```bash
# URL: https://kube.aleklab.com
# Username: admin

# Get bootstrap password (first login only)
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

#### ArgoCD
```bash
# URL: https://argo.aleklab.com
# Username: admin

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Login via CLI
argocd login argo.aleklab.com --username admin --password <password>
```

#### Grafana
```bash
# URL: https://grafana.aleklab.com
# Username: admin

# Get admin password
kubectl -n monitoring get secret grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

#### GitLab
```bash
# URL: https://gitlab.aleklab.com
# Username: root

# Get root password
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

#### OpenBao (Vault)
```bash
# URL: https://vault.aleklab.com

# Get root token (if initialized)
kubectl -n openbao exec openbao-0 -- cat /vault/data/init.json 2>/dev/null || \
  echo "OpenBao not initialized. Run: kubectl -n openbao exec -it openbao-0 -- bao operator init"
```

### 3.3 SSH Access to Nodes

```bash
# Get node IPs
kubectl get nodes -o wide

# SSH to nodes (requires SSH key in Hetzner)
ssh root@<node-public-ip>

# Alternative using Hetzner CLI
hcloud server list
hcloud server ssh rke2-node-1
```

---

## 4. Infrastructure Management (Terraform)

### 4.1 Terraform State Overview

```bash
cd infrastructure

# Initialize Terraform
terraform init

# View current state
terraform show

# List resources
terraform state list
```

### 4.2 Common Terraform Operations

#### View Infrastructure Plan
```bash
terraform plan -out=tfplan
```

#### Apply Changes
```bash
# Apply with plan file
terraform apply tfplan

# Apply directly (interactive)
terraform apply
```

#### Destroy Specific Resources
```bash
# Destroy a specific resource
terraform destroy -target=hcloud_server.node[2]

# Destroy entire infrastructure (DANGEROUS)
terraform destroy
```

### 4.3 Scaling Nodes

To change node count, modify `main.tf`:

```hcl
# Change count from 3 to desired number
resource "hcloud_server" "node" {
  count = 3  # Change this value
  # ...
}
```

```bash
# Validate changes
terraform validate

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

### 4.4 Upgrading Server Type

```bash
# Edit variables.tf or terraform.tfvars
# server_type = "cx51"  # Upgrade from cx43

terraform plan
terraform apply
```

> **Warning**: Upgrading server type requires server restart and will cause brief downtime.

### 4.5 Adding DNS Records

```hcl
# Add to locals.app_subdomains in main.tf
locals {
  app_subdomains = [
    var.argocd_subdomain,
    var.grafana_subdomain,
    "newapp",  # Add new subdomain here
    # ...
  ]
}
```

```bash
# Add variable in variables.tf
variable "newapp_subdomain" {
  description = "Subdomain for NewApp"
  type        = string
  default     = "newapp"
}
```

---

## 5. GitOps & ArgoCD Operations

### 5.1 ArgoCD Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ArgoCD (HA Mode)                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐      │
│  │  API Server │  │ Repo Server │  │ Application Controller│     │
│  │  (3 replicas)│  │ (3 replicas)│  │    (1 replica)       │     │
│  └─────────────┘  └─────────────┘  └─────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   Git Repository │
                    │   (gitops/apps/) │
                    └─────────────────┘
```

### 5.2 App of Apps Pattern

The root application (`gitops/root.yaml`) deploys all other applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap-root
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/vyrti/infra-hetzner-rancher-gitops.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 5.3 Common ArgoCD Commands

```bash
# List all applications
kubectl get applications -n argocd
argocd app list

# Get application details
argocd app get grafana

# Sync application manually
argocd app sync grafana

# Hard refresh (clear cache)
argocd app get grafana --hard-refresh

# Force sync with replace
argocd app sync grafana --force --replace

# View sync status
argocd app wait grafana --health
```

### 5.4 Application Health & Sync Status

```bash
# Check all application status
kubectl get applications -n argocd -o wide

# Get detailed status for specific app
kubectl get application -n argocd grafana -o yaml | yq '.status'

# Watch applications
kubectl get applications -n argocd -w
```

### 5.5 Force Refresh Application

```bash
# Hard refresh to pull latest from Git
kubectl -n argocd patch application grafana \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Refresh all applications
for app in $(kubectl get applications -n argocd -o name); do
  kubectl -n argocd patch $app --type merge \
    -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
done
```

### 5.6 Sync Waves

Applications are deployed in order using sync-wave annotations:

| Wave | Applications |
|------|--------------|
| -2 | hcloud-csi, hcloud-ccm |
| 0 | Crossplane, Kyverno, KEDA, VPA, External Secrets, ExternalDNS, Mimir |
| 1 | Loki, Tempo, Alloy, Istiod, Falco, node-exporter |
| 2 | Grafana, Velero, OpenBao, Kubecost, Trivy, Argo Workflows, MLflow |
| 3 | GitLab |

---

## 6. Application Updates - Complete Guide

### 6.1 Update Procedure Overview

1. **Check current version** in ArgoCD or YAML
2. **Find latest version** from Helm repository
3. **Update version** in GitOps YAML
4. **Commit and push** to Git
5. **Monitor sync** in ArgoCD
6. **Verify** application health

### 6.2 Finding Latest Versions

```bash
# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo add traefik https://traefik.github.io/charts
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add openbao https://openbao.github.io/openbao-helm
helm repo add kedacore https://kedacore.github.io/charts
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo add external-secrets https://charts.external-secrets.io
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo add hetzner https://charts.hetzner.cloud
helm repo add gitlab https://charts.gitlab.io

# Update all repos
helm repo update

# Search for specific chart versions
helm search repo grafana/grafana --versions | head -10
helm search repo grafana/mimir-distributed --versions | head -10
helm search repo grafana/loki --versions | head -10
```

### 6.3 Individual Application Update Procedures

#### 6.3.1 Grafana

```bash
# Check current version
kubectl get application -n argocd grafana -o jsonpath='{.spec.source.targetRevision}'

# Find latest version
helm search repo grafana/grafana --versions | head -5

# Update gitops/apps/grafana.yaml
# Change: targetRevision: 10.3.2 to latest

# Commit and push
cd gitops
git add apps/grafana.yaml
git commit -m "chore: update Grafana to v10.x.x"
git push

# Force sync
argocd app sync grafana

# Verify
kubectl -n monitoring rollout status deployment/grafana
kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana
```

#### 6.3.2 Mimir

```bash
# Check current version
helm search repo grafana/mimir-distributed --versions | head -5

# Update gitops/apps/mimir.yaml
# Change: targetRevision: 6.0.5

# Important: Mimir updates may require storage migrations
# Always check release notes at:
# https://github.com/grafana/mimir/releases

# Commit and sync
git add apps/mimir.yaml
git commit -m "chore: update Mimir to v6.x.x"
git push

# Monitor rollout
kubectl -n mimir get pods -w
```

#### 6.3.3 Loki

```bash
# Check latest version
helm search repo grafana/loki --versions | head -5

# Update gitops/apps/loki.yaml
# Change: targetRevision: 6.49.0

# Loki schema changes require careful migration
# Review: https://grafana.com/docs/loki/latest/operations/storage/schema/

git add apps/loki.yaml
git commit -m "chore: update Loki to v6.x.x"
git push

kubectl -n monitoring rollout status deployment/loki
```

#### 6.3.4 Tempo

```bash
helm search repo grafana/tempo --versions | head -5

# Update gitops/apps/tempo.yaml
# Change: targetRevision: 1.24.1

git add apps/tempo.yaml
git commit -m "chore: update Tempo to v1.x.x"
git push
```

#### 6.3.5 Alloy

```bash
helm search repo grafana/alloy --versions | head -5

# Update gitops/apps/alloy.yaml
# Change: targetRevision: 1.5.1

# Note: Alloy config syntax may change between versions
# Review: https://grafana.com/docs/alloy/latest/

git add apps/alloy.yaml
git commit -m "chore: update Alloy to v1.x.x"
git push

# Alloy runs as DaemonSet
kubectl -n monitoring rollout status daemonset/alloy
```

#### 6.3.6 Kyverno

```bash
helm search repo kyverno/kyverno --versions | head -5

# Update gitops/apps/kyverno.yaml
# Change: targetRevision: 3.6.1

# Important: Kyverno major updates may change policy CRDs
# Always backup policies first:
kubectl get clusterpolicies -o yaml > kyverno-policies-backup.yaml

git add apps/kyverno.yaml
git commit -m "chore: update Kyverno to v3.x.x"
git push
```

#### 6.3.7 Trivy Operator

```bash
helm search repo aquasecurity/trivy-operator --versions | head -5

# Update gitops/apps/trivy.yaml
# Change: targetRevision: 0.20.1

git add apps/trivy.yaml
git commit -m "chore: update Trivy to v0.x.x"
git push
```

#### 6.3.8 Falco

```bash
helm search repo falcosecurity/falco --versions | head -5

# Update gitops/apps/falco.yaml
# Change: targetRevision: 7.0.2

git add apps/falco.yaml
git commit -m "chore: update Falco to v7.x.x"
git push

# Falco runs as DaemonSet
kubectl -n falco rollout status daemonset/falco
```

#### 6.3.9 Istio

Istio requires updating BOTH base and istiod:

```bash
helm search repo istio/base --versions | head -5
helm search repo istio/istiod --versions | head -5

# Update gitops/apps/istio.yaml (BOTH resources)
# Change: targetRevision: 1.24.2 for both

# Important: Follow Istio upgrade guide:
# https://istio.io/latest/docs/setup/upgrade/

git add apps/istio.yaml
git commit -m "chore: update Istio to v1.24.x"
git push

# Verify
istioctl version
kubectl -n istio-system get pods
```

#### 6.3.10 Velero

```bash
helm search repo vmware-tanzu/velero --versions | head -5

# Update gitops/apps/velero.yaml
# Change: targetRevision: 11.2.0
# Also update image.tag: v1.17.1 and plugin versions

# Verify backup compatibility first!
velero backup get

git add apps/velero.yaml
git commit -m "chore: update Velero to v11.x.x"
git push
```

#### 6.3.11 GitLab

```bash
helm search repo gitlab/gitlab --versions | head -5

# GitLab updates are complex - always review:
# https://docs.gitlab.com/charts/installation/upgrade.html

# Create backup before upgrading
velero backup create pre-gitlab-upgrade --include-namespaces gitlab

# Update gitops/apps/gitlab.yaml
# Change: targetRevision: 9.6.2

git add apps/gitlab.yaml
git commit -m "chore: update GitLab to v9.x.x"
git push

# Monitor - GitLab takes time
kubectl -n gitlab get pods -w
```

#### 6.3.12 KEDA

```bash
helm search repo kedacore/keda --versions | head -5

# Update gitops/apps/keda.yaml
# Change: targetRevision: 2.18.2

git add apps/keda.yaml
git commit -m "chore: update KEDA to v2.x.x"
git push
```

#### 6.3.13 VPA

```bash
helm search repo fairwinds-stable/vpa --versions | head -5

# Update gitops/apps/vpa.yaml
# Change: targetRevision: 4.10.1

git add apps/vpa.yaml
git commit -m "chore: update VPA to v4.x.x"
git push
```

#### 6.3.14 External Secrets

```bash
helm search repo external-secrets/external-secrets --versions | head -5

# Update gitops/apps/external-secrets.yaml
# Change: targetRevision: 0.20.4

git add apps/external-secrets.yaml
git commit -m "chore: update External Secrets to v0.x.x"
git push
```

#### 6.3.15 ExternalDNS

```bash
helm search repo external-dns/external-dns --versions | head -5

# Update gitops/apps/external-dns.yaml
# Change: targetRevision: 1.19.0

git add apps/external-dns.yaml
git commit -m "chore: update ExternalDNS to v1.x.x"
git push
```

#### 6.3.16 Crossplane

```bash
helm search repo crossplane-stable/crossplane --versions | head -5

# Update gitops/apps/crossplane.yaml
# Change: targetRevision: 2.1.3

# Warning: Crossplane major updates may affect providers
# Review: https://docs.crossplane.io/latest/software/upgrade/

git add apps/crossplane.yaml
git commit -m "chore: update Crossplane to v2.x.x"
git push
```

#### 6.3.17 OpenBao

```bash
helm search repo openbao/openbao --versions | head -5

# Update gitops/apps/openbao.yaml
# Change: targetRevision: 0.21.2

git add apps/openbao.yaml
git commit -m "chore: update OpenBao to v0.x.x"
git push
```

#### 6.3.18 Kubecost

```bash
helm search repo kubecost/cost-analyzer --versions | head -5

# Update gitops/apps/kubecost.yaml
# Change: targetRevision: 2.5.5

git add apps/kubecost.yaml
git commit -m "chore: update Kubecost to v2.x.x"
git push
```

#### 6.3.19 MLflow

```bash
helm search repo community-charts/mlflow --versions | head -5

# Update gitops/apps/mlflow.yaml
# Change: targetRevision: 1.8.1

git add apps/mlflow.yaml
git commit -m "chore: update MLflow to v1.x.x"
git push
```

#### 6.3.20 Argo Workflows

```bash
helm search repo argoproj/argo-workflows --versions | head -5

# Update gitops/apps/argo-workflows.yaml
# Change: targetRevision: 0.46.2

git add apps/argo-workflows.yaml
git commit -m "chore: update Argo Workflows to v0.x.x"
git push
```

#### 6.3.21 Hetzner Cloud CSI

```bash
helm search repo hetzner/hcloud-csi --versions | head -5

# Update gitops/apps/hcloud-csi.yaml
# Change: targetRevision: 2.18.3

git add apps/hcloud-csi.yaml
git commit -m "chore: update hcloud-csi to v2.x.x"
git push
```

#### 6.3.22 Hetzner Cloud CCM

```bash
helm search repo hetzner/hcloud-cloud-controller-manager --versions | head -5

# Update gitops/apps/hcloud-ccm.yaml
# Change: targetRevision: 1.27.0

git add apps/hcloud-ccm.yaml
git commit -m "chore: update hcloud-ccm to v1.x.x"
git push
```

#### 6.3.23 kube-state-metrics

```bash
helm search repo prometheus-community/kube-state-metrics --versions | head -5

# Update gitops/apps/kube-state-metrics.yaml
# Change: targetRevision: 7.0.0

git add apps/kube-state-metrics.yaml
git commit -m "chore: update kube-state-metrics to v7.x.x"
git push
```

#### 6.3.24 node-exporter

```bash
helm search repo prometheus-community/prometheus-node-exporter --versions | head -5

# Update gitops/apps/node-exporter.yaml
# Change: targetRevision: 4.49.2

git add apps/node-exporter.yaml
git commit -m "chore: update node-exporter to v4.x.x"
git push
```

### 6.4 Bulk Update Script

```bash
#!/bin/bash
# Script: update-all-charts.sh
# Updates all Helm chart versions in gitops/apps/

set -e

APPS_DIR="gitops/apps"

# Define chart mappings: filename -> repo/chart
declare -A CHARTS=(
  ["grafana.yaml"]="grafana/grafana"
  ["mimir.yaml"]="grafana/mimir-distributed"
  ["loki.yaml"]="grafana/loki"
  ["tempo.yaml"]="grafana/tempo"
  ["alloy.yaml"]="grafana/alloy"
  ["kyverno.yaml"]="kyverno/kyverno"
  ["trivy.yaml"]="aquasecurity/trivy-operator"
  ["falco.yaml"]="falcosecurity/falco"
  ["velero.yaml"]="vmware-tanzu/velero"
  ["keda.yaml"]="kedacore/keda"
  ["vpa.yaml"]="fairwinds-stable/vpa"
)

echo "Updating Helm repos..."
helm repo update

echo ""
echo "Current vs Latest versions:"
echo "=========================="

for file in "${!CHARTS[@]}"; do
  chart="${CHARTS[$file]}"
  current=$(grep "targetRevision:" "$APPS_DIR/$file" | head -1 | awk '{print $2}')
  latest=$(helm search repo "$chart" --versions | head -2 | tail -1 | awk '{print $2}')
  
  if [ "$current" != "$latest" ]; then
    echo "⚠️  $file: $current → $latest"
  else
    echo "✓  $file: $current (up to date)"
  fi
done
```

---

## 7. Rancher Management

### 7.1 Rancher Architecture

Rancher is deployed via Helm in the bootstrap process (`cloud-init.yaml`):

```yaml
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=${rancher_hostname} \
  --set bootstrapPassword=admin \
  --set replicas=3 \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=${letsencrypt_email} \
  --set letsEncrypt.ingress.class=traefik \
  --set ingress.ingressClassName=traefik
```

### 7.2 Accessing Rancher

```bash
# URL
open https://kube.aleklab.com

# Get bootstrap password
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'

# After first login, set a new admin password in the UI
```

### 7.3 Updating Rancher

```bash
# Add/update Rancher repo
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# Check current version
helm list -n cattle-system

# Check available versions
helm search repo rancher-latest/rancher --versions | head -10

# Backup before upgrade
velero backup create pre-rancher-upgrade --include-namespaces cattle-system

# Upgrade Rancher
helm upgrade rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=kube.aleklab.com \
  --set replicas=3 \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=admin@aleklab.com \
  --set letsEncrypt.ingress.class=traefik \
  --set ingress.ingressClassName=traefik \
  --version 2.10.x  # Specify version

# Monitor upgrade
kubectl -n cattle-system rollout status deployment/rancher

# Verify
kubectl -n cattle-system get pods
```

### 7.4 Rancher Troubleshooting

```bash
# Check Rancher logs
kubectl -n cattle-system logs -l app=rancher --tail=100

# Check Rancher deployment
kubectl -n cattle-system describe deployment rancher

# Check ingress
kubectl -n cattle-system get ingress

# Check certificate
kubectl -n cattle-system get certificate

# Force restart
kubectl -n cattle-system rollout restart deployment rancher
```

---

## 8. Provisioning New Clusters

### 8.1 Clone Infrastructure for New Cluster

```bash
# Create new directory for additional cluster
mkdir -p ~/infra/hetzner-cluster-2
cp -r infrastructure/* ~/infra/hetzner-cluster-2/

cd ~/infra/hetzner-cluster-2
```

### 8.2 Modify Terraform Configuration

Edit `terraform.tfvars`:

```hcl
# terraform.tfvars for new cluster
hcloud_token         = "your-hetzner-token"
cloudflare_api_token = "your-cloudflare-token"
ssh_key_names        = ["your-ssh-key"]

# Change these for new cluster
subdomain    = "cluster2"
domain_name  = "aleklab.com"
location     = "nbg1"  # Different location
server_type  = "cx43"
email        = "admin@aleklab.com"

# Update subdomains
argocd_subdomain  = "argo-cluster2"
grafana_subdomain = "grafana-cluster2"
```

Edit `main.tf` to change resource names:

```hcl
resource "hcloud_network" "rke2_net" {
  name     = "rke2-cluster2-network"  # Unique name
  ip_range = "10.1.0.0/16"            # Different CIDR
}

resource "hcloud_server" "node" {
  count = 3
  name  = "rke2-cluster2-node-${count.index + 1}"  # Unique names
  # ...
}
```

### 8.3 Deploy New Cluster

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Wait for completion (15-20 minutes)
# Terraform will:
# 1. Create Hetzner network, load balancer, servers
# 2. Bootstrap RKE2 cluster
# 3. Install Traefik, Cert-Manager, Rancher
# 4. Install ArgoCD
# 5. Create DNS records in Cloudflare
```

### 8.4 Configure New Cluster

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/rke2.yaml

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Apply GitOps root application
kubectl apply -f ../gitops/root.yaml
```

### 8.5 Multi-Cluster GitOps

For managing multiple clusters with single GitOps repo:

```bash
# Create cluster-specific overlays
mkdir -p gitops/clusters/cluster-1
mkdir -p gitops/clusters/cluster-2

# Use Kustomize overlays
# gitops/clusters/cluster-1/kustomization.yaml
cat <<EOF > gitops/clusters/cluster-1/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../apps

patchesStrategicMerge:
  - grafana-patch.yaml
EOF

# Patch for cluster-specific values
cat <<EOF > gitops/clusters/cluster-1/grafana-patch.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
spec:
  source:
    helm:
      values: |
        ingress:
          hosts:
            - grafana-cluster1.aleklab.com
EOF
```

---

## 9. Adding Clusters to Rancher (Terraform)

### 9.1 Rancher Terraform Provider Setup

```hcl
# providers.tf
terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.0"
    }
  }
}

provider "rancher2" {
  api_url   = "https://kube.aleklab.com"
  token_key = var.rancher_api_token
  insecure  = false
}

variable "rancher_api_token" {
  description = "Rancher API token"
  type        = string
  sensitive   = true
}
```

### 9.2 Generate Rancher API Token

```bash
# In Rancher UI:
# 1. Go to User Avatar → Account & API Keys
# 2. Create new API Key
# 3. Choose "No Scope" for cluster management
# 4. Copy the Bearer Token

# Or via kubectl:
kubectl apply -f - <<EOF
apiVersion: management.cattle.io/v3
kind: Token
metadata:
  name: terraform-token
  namespace: local
spec:
  clusterName: local
  description: "Terraform automation token"
  ttl: 0
  userId: user-xxxxx  # Get from Rancher
EOF
```

### 9.3 Import Existing Cluster

```hcl
# rancher-import.tf

# Create cluster in Rancher (import mode)
resource "rancher2_cluster" "imported_cluster" {
  name        = "hetzner-cluster-2"
  description = "Secondary Hetzner RKE2 cluster"
  
  # Labels for organization
  labels = {
    environment = "production"
    provider    = "hetzner"
    region      = "nbg1"
  }
}

# Output registration command
output "cluster_registration_command" {
  value     = rancher2_cluster.imported_cluster.cluster_registration_token[0].command
  sensitive = true
}
```

### 9.4 Apply and Register

```bash
# Apply Rancher config
terraform apply

# Get registration command
terraform output -raw cluster_registration_command

# Run on target cluster
export KUBECONFIG=~/infra/hetzner-cluster-2/rke2.yaml
# Paste and run the registration command output

# Example command format:
kubectl apply -f https://kube.aleklab.com/v3/import/xxxxx.yaml
```

### 9.5 Create Managed Cluster (RKE2)

For Rancher to fully manage the cluster:

```hcl
# rancher-managed-cluster.tf

resource "rancher2_cluster_v2" "managed_cluster" {
  name               = "hetzner-managed-cluster"
  kubernetes_version = "v1.30.6+rke2r1"
  
  rke_config {
    machine_global_config = <<EOF
cni: canal
disable:
  - rke2-ingress-nginx
EOF

    machine_pools {
      name                         = "control-plane"
      cloud_credential_secret_name = rancher2_cloud_credential.hetzner.id
      control_plane_role          = true
      etcd_role                   = true
      worker_role                 = true
      quantity                    = 3
      
      machine_config {
        kind = rancher2_machine_config_v2.hetzner.kind
        name = rancher2_machine_config_v2.hetzner.name
      }
    }
  }
}

resource "rancher2_cloud_credential" "hetzner" {
  name = "hetzner-credential"
  hetzner_credential_config {
    api_token = var.hcloud_token
  }
}

resource "rancher2_machine_config_v2" "hetzner" {
  generate_name = "hetzner-config"
  hetzner_config {
    image         = "ubuntu-24.04"
    server_type   = "cx43"
    server_location = "nbg1"
    networks      = [hcloud_network.rke2_net.id]
  }
}
```

### 9.6 Cluster Management via Terraform

```hcl
# Manage cluster settings
resource "rancher2_cluster_sync" "sync" {
  cluster_id = rancher2_cluster_v2.managed_cluster.id
}

# Add project
resource "rancher2_project" "production" {
  cluster_id = rancher2_cluster_sync.sync.cluster_id
  name       = "production"
  
  resource_quota {
    project_limit {
      limits_cpu    = "4000m"
      limits_memory = "8192Mi"
    }
  }
}

# Add namespace to project
resource "rancher2_namespace" "app" {
  name       = "my-application"
  project_id = rancher2_project.production.id
}
```

---

## 10. Adding Clusters to Rancher (Crossplane)

### 10.1 Install Crossplane Provider for Rancher

```yaml
# gitops/apps/crossplane-rancher-provider.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane-rancher-provider
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-repo/crossplane-configs
    path: rancher-provider
  destination:
    server: https://kubernetes.default.svc
    namespace: crossplane-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 10.2 Crossplane Provider Configuration

```yaml
# provider-rancher.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-rancher
spec:
  package: "xpkg.upbound.io/upbound/provider-rancher:v0.1.0"
---
apiVersion: v1
kind: Secret
metadata:
  name: rancher-credentials
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    {
      "api_url": "https://kube.aleklab.com",
      "token_key": "token-xxxxx:xxxxxxxxxxxxxxxxxxxxxxxx",
      "insecure": false
    }
---
apiVersion: rancher.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: rancher-credentials
      key: credentials
```

### 10.3 Import Cluster via Crossplane

```yaml
# cluster-import.yaml
apiVersion: management.rancher.upbound.io/v1alpha1
kind: Cluster
metadata:
  name: imported-cluster-2
spec:
  forProvider:
    name: hetzner-cluster-2
    description: "Imported via Crossplane"
    labels:
      environment: production
      managed-by: crossplane
  providerConfigRef:
    name: default
```

### 10.4 Composing Clusters with Crossplane

```yaml
# composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: rancher-cluster-composition
spec:
  compositeTypeRef:
    apiVersion: platform.aleklab.com/v1alpha1
    kind: XRancherCluster
  
  resources:
    - name: cluster
      base:
        apiVersion: management.rancher.upbound.io/v1alpha1
        kind: Cluster
        spec:
          forProvider:
            labels:
              managed-by: crossplane
      patches:
        - fromFieldPath: "spec.clusterName"
          toFieldPath: "spec.forProvider.name"
        - fromFieldPath: "spec.environment"
          toFieldPath: "spec.forProvider.labels.environment"
---
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xrancherclusters.platform.aleklab.com
spec:
  group: platform.aleklab.com
  names:
    kind: XRancherCluster
    plural: xrancherclusters
  claimNames:
    kind: RancherCluster
    plural: rancherclusters
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                clusterName:
                  type: string
                environment:
                  type: string
                  enum: [development, staging, production]
              required:
                - clusterName
                - environment
```

### 10.5 Creating Cluster via Claim

```yaml
# my-cluster-claim.yaml
apiVersion: platform.aleklab.com/v1alpha1
kind: RancherCluster
metadata:
  name: production-cluster-3
  namespace: default
spec:
  clusterName: hetzner-prod-3
  environment: production
```

```bash
# Apply the claim
kubectl apply -f my-cluster-claim.yaml

# Watch status
kubectl get rancherclusters -w

# Check Crossplane resources
kubectl get managed
```

---

## 11. Monitoring Stack Operations

### 11.1 Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Grafana                                  │
│                    (Unified Dashboard)                           │
└───────────────────────────┬─────────────────────────────────────┘
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
                    └───────────────┘
```

### 11.2 Checking Metrics Pipeline

```bash
# Verify Alloy is scraping
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=50

# Check kube-state-metrics
kubectl -n monitoring get pods -l app.kubernetes.io/name=kube-state-metrics

# Check node-exporter (DaemonSet)
kubectl -n monitoring get pods -l app.kubernetes.io/name=prometheus-node-exporter

# Test Mimir API
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s "http://mimir-gateway.mimir.svc.cluster.local:80/prometheus/api/v1/query?query=up"
```

### 11.3 Checking Logs Pipeline

```bash
# Verify Loki is receiving logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=50

# Test Loki API
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s "http://loki-gateway.monitoring.svc.cluster.local:80/loki/api/v1/labels"

# Query specific namespace logs
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s 'http://loki-gateway.monitoring.svc.cluster.local:80/loki/api/v1/query_range' \
  --data-urlencode 'query={namespace="kube-system"}' \
  --data-urlencode 'limit=10'
```

### 11.4 Checking Traces Pipeline

```bash
# Verify Tempo is running
kubectl -n monitoring get pods -l app.kubernetes.io/name=tempo

# Check Tempo service
kubectl -n monitoring get svc tempo

# Traces are received via OTLP on ports 4317 (gRPC) and 4318 (HTTP)
```

### 11.5 Common Monitoring Issues

```bash
# Issue: No metrics in Grafana
# Check 1: Alloy scraping targets
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy | grep -i "error"

# Check 2: Mimir ingestion
kubectl logs -n mimir -l app.kubernetes.io/component=distributor | tail -20

# Check 3: Grafana datasource connection
kubectl exec -it -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') \
  -c grafana -- cat /etc/grafana/provisioning/datasources/datasources.yaml

# Issue: No logs in Grafana
# Check Loki single binary
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=100

# Issue: High memory usage on Mimir
# Check storage size
kubectl exec -n mimir -it mimir-ingester-0 -- df -h /data
```

### 11.6 Scaling Monitoring Components

```yaml
# Scale Mimir ingester (update in mimir.yaml)
ingester:
  replicas: 2  # Increase from 1
  persistentVolume:
    size: 10Gi  # Increase storage

# Scale Loki (switch from SingleBinary to distributed)
deploymentMode: Distributed
read:
  replicas: 2
write:
  replicas: 2
backend:
  replicas: 2
```

---

## 12. Security Stack Operations

### 12.1 Kyverno Policy Management

```bash
# List all policies
kubectl get clusterpolicies
kubectl get policies -A

# Get policy details
kubectl describe clusterpolicy <policy-name>

# Check policy reports
kubectl get policyreport -A
kubectl get clusterpolicyreport

# View violations
kubectl get policyreport -A -o json | jq '.items[].results[] | select(.result=="fail")'
```

### 12.2 Creating Kyverno Policies

```yaml
# Example: Require resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-limits
spec:
  validationFailureAction: Enforce  # or "Audit"
  rules:
    - name: require-limits
      match:
        any:
        - resources:
            kinds:
              - Pod
      validate:
        message: "CPU and memory limits are required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

```bash
# Apply policy
kubectl apply -f require-limits.yaml

# Test policy
kubectl run test --image=nginx --dry-run=server
# Should fail without limits
```

### 12.3 Trivy Security Scanning

```bash
# List vulnerability reports
kubectl get vulnerabilityreports -A

# Get specific report
kubectl get vulnerabilityreport -n gitlab \
  -o json | jq '.items[].report.vulnerabilities[] | select(.severity=="CRITICAL")'

# List config audit reports
kubectl get configauditreports -A

# Check compliance reports
kubectl get clustercompliancereports
```

### 12.4 Falco Runtime Security

```bash
# Check Falco status
kubectl -n falco get pods

# View Falco alerts
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=100

# Check for security events
kubectl -n falco logs -l app.kubernetes.io/name=falco | grep -i "Warning\|Error\|Critical"

# Test Falco detection
kubectl run test --image=alpine -- /bin/sh -c "cat /etc/shadow"
# Should trigger Falco alert
```

### 12.5 Security Best Practices Checklist

```bash
#!/bin/bash
# security-audit.sh - Quick security audit

echo "=== Security Audit ==="

echo -e "\n1. Checking pods running as root..."
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.runAsUser == 0) | .metadata.namespace + "/" + .metadata.name'

echo -e "\n2. Checking pods with privileged containers..."
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | .metadata.namespace + "/" + .metadata.name'

echo -e "\n3. Checking for secrets in env vars..."
kubectl get pods -A -o json | jq -r '.items[].spec.containers[].env[]? | select(.valueFrom.secretKeyRef != null) | .name'

echo -e "\n4. Checking network policies..."
kubectl get networkpolicies -A

echo -e "\n5. Checking Kyverno violations..."
kubectl get policyreport -A -o json | jq '.items[].results[]? | select(.result=="fail") | .rule'

echo -e "\n6. Checking Trivy critical vulnerabilities..."
kubectl get vulnerabilityreports -A -o json | jq '[.items[].report.vulnerabilities[]? | select(.severity=="CRITICAL")] | length'
```

---

## 13. Backup & Disaster Recovery

### 13.1 Velero Backup Architecture

```
┌────────────────────────────────────────────────────────┐
│                    Velero Server                        │
│                  (Deployment + ServiceAccount)          │
└───────────────────────────┬────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
    ┌───────────────┐               ┌───────────────┐
    │  Node Agent   │               │    MinIO      │
    │  (DaemonSet)  │               │  (S3 Storage) │
    │  Kopia backup │               │  velero-minio │
    └───────────────┘               └───────────────┘
```

### 13.2 Backup Schedules

| Schedule | Time | Retention | Namespaces |
|----------|------|-----------|------------|
| daily-backup | 3:00 AM | 7 days | gitlab, openbao, monitoring, kubecost |
| weekly-full-backup | Sunday 4:00 AM | 30 days | All (except kube-system) |

### 13.3 Velero Operations

```bash
# List backups
velero backup get

# Create manual backup
velero backup create manual-backup-$(date +%Y%m%d) \
  --include-namespaces gitlab,openbao \
  --wait

# Backup with specific resources
velero backup create secrets-backup \
  --include-resources secrets \
  --include-namespaces gitlab

# Backup entire cluster
velero backup create full-cluster-$(date +%Y%m%d) \
  --exclude-namespaces kube-system,kube-public

# View backup details
velero backup describe manual-backup-20241220 --details

# View backup logs
velero backup logs manual-backup-20241220
```

### 13.4 Restore Operations

```bash
# List available backups
velero backup get

# Restore entire backup
velero restore create --from-backup manual-backup-20241220

# Restore to different namespace
velero restore create --from-backup gitlab-backup \
  --namespace-mappings gitlab:gitlab-restore

# Restore specific resources only
velero restore create --from-backup full-backup \
  --include-resources deployments,configmaps \
  --include-namespaces gitlab

# Check restore status
velero restore get
velero restore describe <restore-name>
```

### 13.5 Disaster Recovery Procedures

#### Scenario 1: Namespace Deleted
```bash
# Find most recent backup
velero backup get | grep daily

# Restore namespace
velero restore create --from-backup daily-backup-20241220 \
  --include-namespaces gitlab

# Verify
kubectl get pods -n gitlab
```

#### Scenario 2: Complete Cluster Failure
```bash
# 1. Provision new cluster (Section 8)
terraform apply

# 2. Install Velero on new cluster
kubectl apply -f gitops/apps/velero.yaml

# 3. Wait for Velero and MinIO
kubectl -n velero get pods -w

# 4. Configure backup location (same MinIO)
velero backup-location get

# 5. Restore from backup
velero restore create --from-backup weekly-full-backup-20241215 \
  --exclude-namespaces kube-system,kube-public,velero

# 6. Verify applications
kubectl get pods -A
```

#### Scenario 3: Rollback After Failed Upgrade
```bash
# Before upgrade, create backup
velero backup create pre-upgrade-$(date +%Y%m%d) \
  --include-namespaces gitlab

# If upgrade fails, delete and restore
kubectl delete namespace gitlab
velero restore create --from-backup pre-upgrade-20241220 \
  --include-namespaces gitlab
```

### 13.6 Backup Verification

```bash
# Verify backup storage location
velero backup-location get

# Check MinIO connectivity
kubectl exec -n velero deployment/velero -- \
  velero backup-location get

# List files in MinIO
kubectl exec -n velero deployment/velero-minio -- \
  mc ls minio/velero-backups

# Validate backup
velero backup describe <backup-name> --details | grep "Phase:"
# Should show "Completed"
```

---

## 14. Secrets Management

### 14.1 OpenBao (Vault) Operations

```bash
# Check OpenBao status
kubectl -n openbao get pods

# Initialize OpenBao (first time only)
kubectl -n openbao exec -it openbao-0 -- bao operator init

# Unseal OpenBao
kubectl -n openbao exec -it openbao-0 -- bao operator unseal <key>

# Login
kubectl -n openbao exec -it openbao-0 -- bao login

# Enable KV secrets engine
kubectl -n openbao exec -it openbao-0 -- bao secrets enable -path=secret kv-v2

# Create secret
kubectl -n openbao exec -it openbao-0 -- \
  bao kv put secret/myapp password=mysecret

# Read secret
kubectl -n openbao exec -it openbao-0 -- \
  bao kv get secret/myapp
```

### 14.2 External Secrets Operator

```bash
# Check External Secrets status
kubectl get externalsecrets -A
kubectl get clustersecretstores
kubectl get secretstores -A

# Create ClusterSecretStore for OpenBao
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: openbao-backend
spec:
  provider:
    vault:
      server: "http://openbao.openbao.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: openbao-token
          key: token
          namespace: external-secrets
EOF

# Create ExternalSecret
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-secret
  namespace: default
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: openbao-backend
    kind: ClusterSecretStore
  target:
    name: myapp-credentials
  data:
    - secretKey: password
      remoteRef:
        key: secret/myapp
        property: password
EOF

# Verify secret was created
kubectl get secret myapp-credentials -o yaml
```

### 14.3 Managing Kubernetes Secrets

```bash
# Create secret from literal
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Create secret from file
kubectl create secret generic tls-secret \
  --from-file=tls.crt=./cert.pem \
  --from-file=tls.key=./key.pem

# Create docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.gitlab.aleklab.com \
  --docker-username=user \
  --docker-password=pass

# View secret (decoded)
kubectl get secret my-secret -o json | jq -r '.data | map_values(@base64d)'

# Rotate secret
kubectl delete secret my-secret
kubectl create secret generic my-secret --from-literal=password=newsecret
```

### 14.4 Required Secrets Reference

| Secret Name | Namespace | Purpose | How to Create |
|-------------|-----------|---------|---------------|
| hcloud | kube-system | Hetzner API token for CCM/CSI | See below |
| cloudflare-api-token | external-dns | Cloudflare DNS management | See below |
| argocd-initial-admin-secret | argocd | ArgoCD admin password | Auto-generated |
| grafana | monitoring | Grafana admin password | Set in Helm values |
| velero-credentials | velero | MinIO credentials | Set in Helm values |

```bash
# Create Hetzner Cloud secret
kubectl create secret generic hcloud \
  --namespace kube-system \
  --from-literal=token=$HCLOUD_TOKEN

# Create Cloudflare secret for ExternalDNS
kubectl create namespace external-dns
kubectl create secret generic cloudflare-api-token \
  --namespace external-dns \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN
```

---

## 15. Service Mesh (Istio) Operations

### 15.1 Istio Components

| Component | Purpose |
|-----------|---------|
| istio-base | CRDs and base configuration |
| istiod | Control plane (Pilot, Citadel, Galley) |
| Envoy sidecars | Data plane proxies |

### 15.2 Enable Sidecar Injection

```bash
# Label namespace for automatic injection
kubectl label namespace default istio-injection=enabled

# Verify label
kubectl get namespace -L istio-injection

# Restart pods to inject sidecars
kubectl rollout restart deployment -n default
```

### 15.3 Istio Operations

```bash
# Check Istio status
istioctl version
istioctl proxy-status

# Analyze configuration
istioctl analyze

# View mesh configuration
kubectl get istiooperator -A
kubectl get peerauthentication -A
kubectl get destinationrule -A
kubectl get virtualservice -A

# Debug sidecar
istioctl proxy-config cluster <pod-name>.<namespace>
istioctl proxy-config route <pod-name>.<namespace>
istioctl proxy-config listener <pod-name>.<namespace>
```

### 15.4 Traffic Management

```yaml
# VirtualService example
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service
  http:
    - route:
        - destination:
            host: my-service
            subset: v1
          weight: 90
        - destination:
            host: my-service
            subset: v2
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-service
spec:
  host: my-service
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

### 15.5 mTLS Configuration

```yaml
# Strict mTLS for namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

---

## 16. CI/CD Platform Operations

### 16.1 GitLab Operations

```bash
# Check GitLab status
kubectl -n gitlab get pods

# View GitLab components
kubectl -n gitlab get deployments

# Check GitLab migrations
kubectl -n gitlab logs -l app=migrations --tail=100

# Rails console access
kubectl -n gitlab exec -it deploy/gitlab-webservice-default -- \
  /srv/gitlab/bin/rails console

# Check runner status (if installed)
kubectl -n gitlab get runners
```

### 16.2 GitLab Backup

```bash
# Create GitLab backup
kubectl -n gitlab exec -it deploy/gitlab-toolbox -- \
  backup-utility --skip registry

# List backups
kubectl -n gitlab exec -it deploy/gitlab-toolbox -- ls -la /srv/gitlab/tmp/backups/

# Restore backup
kubectl -n gitlab exec -it deploy/gitlab-toolbox -- \
  backup-utility --restore -f <backup-timestamp>
```

### 16.3 Argo Workflows

```bash
# Submit workflow
argo submit -n argo workflow.yaml

# List workflows
argo list -n argo

# Get workflow status
argo get -n argo <workflow-name>

# View logs
argo logs -n argo <workflow-name>

# Delete workflow
argo delete -n argo <workflow-name>
```

### 16.4 Example Argo Workflow

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-world-
spec:
  entrypoint: whalesay
  templates:
    - name: whalesay
      container:
        image: docker/whalesay:latest
        command: [cowsay]
        args: ["hello world"]
```

---

## 17. Autoscaling Operations

### 17.1 KEDA (Event-driven Autoscaling)

```bash
# List ScaledObjects
kubectl get scaledobjects -A

# List TriggerAuthentications
kubectl get triggerauthentication -A

# View KEDA operator logs
kubectl logs -n keda -l app=keda-operator

# Check metrics server
kubectl logs -n keda -l app=keda-operator-metrics-apiserver
```

### 17.2 KEDA ScaledObject Example

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: my-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://mimir-gateway.mimir.svc.cluster.local:80/prometheus
        metricName: http_requests_total
        threshold: "100"
        query: sum(rate(http_requests_total{app="my-app"}[2m]))
```

### 17.3 VPA (Vertical Pod Autoscaler)

```bash
# List VPA objects
kubectl get vpa -A

# View recommendations
kubectl describe vpa <vpa-name>

# Check VPA updater logs
kubectl logs -n vpa -l app.kubernetes.io/component=updater
```

### 17.4 VPA Example

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"  # or "Off" for recommendations only
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2
          memory: 4Gi
```

---

## 18. Storage Management

### 18.1 Hetzner CSI Driver

```bash
# Check CSI driver status
kubectl -n kube-system get pods -l app.kubernetes.io/name=hcloud-csi

# List storage classes
kubectl get storageclass

# List PVCs
kubectl get pvc -A

# List PVs
kubectl get pv
```

### 18.2 Storage Class Configuration

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hcloud-volumes
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.hetzner.cloud
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### 18.3 Volume Operations

```bash
# Create PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: hcloud-volumes
  resources:
    requests:
      storage: 10Gi
EOF

# Expand volume (if allowVolumeExpansion: true)
kubectl patch pvc my-data -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Delete PVC
kubectl delete pvc my-data
```

### 18.4 Volume Troubleshooting

```bash
# Check CSI driver logs
kubectl logs -n kube-system -l app.kubernetes.io/name=hcloud-csi -c hcloud-csi-driver

# Check volume attachments
kubectl get volumeattachments

# Describe stuck PVC
kubectl describe pvc <pvc-name>

# Force delete stuck PV
kubectl patch pv <pv-name> -p '{"metadata":{"finalizers":null}}'
kubectl delete pv <pv-name> --force --grace-period=0
```

---

## 19. Network & DNS Management

### 19.1 Traefik Ingress Controller

```bash
# Check Traefik status
kubectl -n traefik get pods

# View Traefik config
kubectl -n traefik get cm traefik -o yaml

# Check IngressRoutes
kubectl get ingressroute -A

# Access Traefik dashboard (if enabled)
kubectl port-forward -n traefik svc/traefik-dashboard 9000:9000
```

### 19.2 ExternalDNS Operations

```bash
# Check ExternalDNS status
kubectl -n external-dns get pods

# View ExternalDNS logs
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns

# List managed DNS records
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns | grep "Updating"
```

### 19.3 Certificate Management

```bash
# List certificates
kubectl get certificates -A

# List certificate requests
kubectl get certificaterequests -A

# Check ClusterIssuer status
kubectl get clusterissuer letsencrypt-prod -o yaml

# Force certificate renewal
kubectl delete secret <secret-name> -n <namespace>
# Certificate will be automatically re-issued

# Debug certificate issues
kubectl describe certificate <cert-name> -n <namespace>
kubectl describe certificaterequest <cert-name> -n <namespace>
```

### 19.4 DNS Troubleshooting

```bash
# Test internal DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Test external DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup grafana.aleklab.com

# Check CoreDNS pods
kubectl -n kube-system get pods -l k8s-app=kube-dns

# View CoreDNS logs
kubectl -n kube-system logs -l k8s-app=kube-dns
```

---

## 20. Troubleshooting Guide

### 20.1 Quick Diagnostic Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes
kubectl top pods -A

# Events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl describe node | grep -A 5 "Allocated resources"
```

### 20.2 Common Issues & Solutions

#### Pods Stuck in Pending
```bash
# Check reason
kubectl describe pod <pod-name> | grep -A 10 "Events:"

# Common causes:
# - Insufficient resources: scale nodes or reduce requests
# - PVC pending: check storage class and CSI
# - Node selector/taint: check pod spec
```

#### Pods CrashLoopBackOff
```bash
# Check logs
kubectl logs <pod-name> --previous

# Check resource limits
kubectl describe pod <pod-name> | grep -A 5 "Limits:"

# Check liveness probe
kubectl describe pod <pod-name> | grep -A 5 "Liveness:"
```

#### ImagePullBackOff
```bash
# Check image name
kubectl describe pod <pod-name> | grep "Image:"

# Check image pull secrets
kubectl get pod <pod-name> -o jsonpath='{.spec.imagePullSecrets}'

# Test pull manually
docker pull <image-name>
```

#### Certificate Issues
```bash
# Check certificate status
kubectl describe certificate <cert-name> -n <namespace>

# Check issuer status
kubectl describe clusterissuer letsencrypt-prod

# Check HTTP-01 challenge
kubectl get challenges -A

# Debug ACME
kubectl logs -n cert-manager deploy/cert-manager
```

### 20.3 Network Troubleshooting

```bash
# Test service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v <service-url>

# Check endpoints
kubectl get endpoints <service-name>

# Check network policy
kubectl get networkpolicy -A

# DNS resolution test
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup <service-name>.<namespace>.svc.cluster.local
```

### 20.4 Storage Troubleshooting

```bash
# Check PVC status
kubectl get pvc -A

# Check PV binding
kubectl get pv

# Check CSI driver
kubectl -n kube-system logs -l app.kubernetes.io/name=hcloud-csi -c hcloud-csi-driver

# Multi-attach error fix
# RWO volumes can't be attached to multiple nodes
# Use strategy: Recreate instead of RollingUpdate
```

### 20.5 Node Troubleshooting

```bash
# SSH to node
ssh root@<node-ip>

# Check RKE2 status
systemctl status rke2-server

# View RKE2 logs
journalctl -u rke2-server -f

# Check kubelet logs
/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml \
  logs -n kube-system kube-apiserver-<node-name>

# Check system resources
top
df -h
free -m
```

---

## 21. Runbooks & Emergency Procedures

### 21.1 Node Failure Runbook

```bash
#!/bin/bash
# runbook-node-failure.sh

NODE=$1

echo "=== Node Failure Runbook for $NODE ==="

echo "1. Check node status..."
kubectl get node $NODE

echo "2. Cordon node..."
kubectl cordon $NODE

echo "3. Check pods on failed node..."
kubectl get pods -A -o wide | grep $NODE

echo "4. Drain node (if accessible)..."
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --force

echo "5. Check if pods rescheduled..."
kubectl get pods -A | grep -v Running

echo "6. If node recoverable, uncordon after fix..."
echo "   kubectl uncordon $NODE"

echo "7. If node unrecoverable, delete..."
echo "   kubectl delete node $NODE"
echo "   terraform apply  # to create replacement"
```

### 21.2 Application Rollback Runbook

```bash
#!/bin/bash
# runbook-rollback.sh

NAMESPACE=$1
DEPLOYMENT=$2

echo "=== Rollback Runbook for $DEPLOYMENT in $NAMESPACE ==="

echo "1. Check deployment history..."
kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE

echo "2. Current status..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

echo "3. Rollback to previous version..."
kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE

echo "4. Wait for rollback..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

echo "5. Verify pods..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$DEPLOYMENT
```

### 21.3 Emergency Backup Runbook

```bash
#!/bin/bash
# runbook-emergency-backup.sh

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Emergency Backup Runbook ==="

echo "1. Create full cluster backup..."
velero backup create emergency-backup-$TIMESTAMP \
  --exclude-namespaces kube-system,kube-public \
  --wait

echo "2. Verify backup..."
velero backup describe emergency-backup-$TIMESTAMP

echo "3. List all backups..."
velero backup get

echo "4. Backup status..."
velero backup describe emergency-backup-$TIMESTAMP --details | grep "Phase:"
```

### 21.4 Certificate Emergency Renewal

```bash
#!/bin/bash
# runbook-cert-renewal.sh

NAMESPACE=$1
SECRET_NAME=$2

echo "=== Certificate Emergency Renewal ==="

echo "1. Delete the secret..."
kubectl delete secret $SECRET_NAME -n $NAMESPACE

echo "2. Wait for cert-manager to re-issue..."
sleep 30

echo "3. Check certificate status..."
kubectl get certificate -n $NAMESPACE

echo "4. Check certificate request..."
kubectl get certificaterequest -n $NAMESPACE

echo "5. Check challenge if pending..."
kubectl get challenge -A
```

### 21.5 Cluster Recovery from Backup

```bash
#!/bin/bash
# runbook-cluster-recovery.sh

BACKUP_NAME=$1

echo "=== Cluster Recovery Runbook ==="

echo "1. Verify backup exists..."
velero backup get | grep $BACKUP_NAME

echo "2. Preview restore..."
velero restore create --from-backup $BACKUP_NAME --dry-run

echo "3. Execute restore..."
velero restore create recovery-$(date +%Y%m%d) --from-backup $BACKUP_NAME \
  --exclude-namespaces kube-system,kube-public,velero

echo "4. Monitor restore..."
velero restore get

echo "5. Verify pods..."
kubectl get pods -A | grep -v Running

echo "6. Check applications..."
kubectl get applications -n argocd
```

---

## 22. Best Practices & Standards

### 22.1 GitOps Workflow

1. **Never make manual changes** to cluster resources
2. **All changes through Git** - commit to gitops repo
3. **Use sync-wave annotations** for deployment order
4. **Create backup before major changes**
5. **Test in staging environment first**

### 22.2 Application Deployment Checklist

```bash
# Pre-deployment
□ Check current version in git
□ Review release notes for breaking changes
□ Create backup of affected namespaces
□ Update version in apps/*.yaml
□ Validate YAML syntax

# Deployment
□ Commit and push to git
□ Monitor ArgoCD sync
□ Watch pod rollout
□ Check logs for errors

# Post-deployment
□ Verify application health
□ Check metrics in Grafana
□ Test application functionality
□ Update documentation if needed
```

### 22.3 Naming Conventions

| Resource | Convention | Example |
|----------|------------|---------|
| Namespaces | lowercase, hyphenated | `gitlab`, `monitoring` |
| Deployments | app-name | `grafana`, `mimir-ingester` |
| Services | app-name | `grafana`, `mimir-gateway` |
| ConfigMaps | app-name-config | `grafana-dashboards` |
| Secrets | app-name-secret | `grafana-tls` |
| PVCs | app-name-data | `grafana-data` |

### 22.4 Resource Limits Standards

```yaml
# Small application
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Medium application
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Large application
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

### 22.5 Monitoring Alerts (Recommended)

```yaml
# Example Mimir alerting rules
groups:
  - name: kubernetes
    rules:
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
      
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.pod }}"
      
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.pod }}"
```

### 22.6 Security Hardening Checklist

```bash
# Cluster
□ Network policies enabled
□ Pod security standards enforced
□ RBAC properly configured
□ Secrets encrypted at rest
□ Audit logging enabled

# Applications
□ No containers running as root
□ Read-only root filesystem where possible
□ Resource limits set
□ Security contexts defined
□ No privileged containers

# Network
□ mTLS enabled (Istio)
□ Ingress TLS configured
□ External access restricted
□ Internal services not exposed
```

### 22.7 Documentation Standards

1. Update `gitops/README.md` when adding new apps
2. Document all credentials in secure location
3. Keep this `maintenance.md` updated
4. Add troubleshooting steps for new issues
5. Document any manual procedures

---

## Appendix A: Quick Reference Commands

```bash
# Cluster
export KUBECONFIG=./infrastructure/rke2.yaml
kubectl get nodes
kubectl get pods -A

# ArgoCD
argocd app list
argocd app sync <app-name>
argocd app get <app-name>

# Velero
velero backup get
velero backup create <name> --include-namespaces <ns>
velero restore create --from-backup <backup>

# Helm
helm list -A
helm search repo <chart>
helm upgrade <release> <chart> --version <version>

# Terraform
terraform plan
terraform apply
terraform state list

# Logs
kubectl logs -n <ns> <pod> --tail=100
kubectl logs -n <ns> -l app=<label>

# Debug
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
kubectl exec -it <pod> -- /bin/sh
```

---

## Appendix B: Important URLs

| Service | URL | Notes |
|---------|-----|-------|
| Rancher | https://kube.aleklab.com | Cluster management |
| ArgoCD | https://argo.aleklab.com | GitOps |
| Grafana | https://grafana.aleklab.com | Observability |
| GitLab | https://gitlab.aleklab.com | Source control |
| Vault | https://vault.aleklab.com | Secrets |
| Kubecost | https://kubecost.aleklab.com | Cost analysis |
| MLflow | https://mlflow.aleklab.com | ML tracking |
| Argo Workflows | https://workflows.aleklab.com | Workflow engine |

---

## Appendix C: Version Matrix

| Component | Current Version | Helm Chart | Namespace |
|-----------|----------------|------------|-----------|
| Mimir | 6.0.5 | grafana/mimir-distributed | mimir |
| Grafana | 10.3.2 | grafana/grafana | monitoring |
| Loki | 6.49.0 | grafana/loki | monitoring |
| Tempo | 1.24.1 | grafana/tempo | monitoring |
| Alloy | 1.5.1 | grafana/alloy | monitoring |
| Kyverno | 3.6.1 | kyverno/kyverno | kyverno |
| Trivy | 0.20.1 | aquasecurity/trivy-operator | trivy-system |
| Falco | 7.0.2 | falcosecurity/falco | falco |
| Istio | 1.24.2 | istio/istiod | istio-system |
| Velero | 11.2.0 | vmware-tanzu/velero | velero |
| GitLab | 9.6.2 | gitlab/gitlab | gitlab |
| KEDA | 2.18.2 | kedacore/keda | keda |
| VPA | 4.10.1 | fairwinds-stable/vpa | vpa |
| External Secrets | 0.20.4 | external-secrets/external-secrets | external-secrets |
| ExternalDNS | 1.19.0 | external-dns/external-dns | external-dns |
| Crossplane | 2.1.3 | crossplane-stable/crossplane | crossplane-system |
| OpenBao | 0.21.2 | openbao/openbao | openbao |
| hcloud-csi | 2.18.3 | hetzner/hcloud-csi | kube-system |
| hcloud-ccm | 1.27.0 | hetzner/hcloud-cloud-controller-manager | kube-system |

---

**Document End**

*This manual should be reviewed and updated quarterly or when significant infrastructure changes occur.*

---

## Appendix D: RKE2 Cluster Management

### D.1 RKE2 Configuration Files

```bash
# RKE2 config location
/etc/rancher/rke2/config.yaml

# RKE2 binaries
/var/lib/rancher/rke2/bin/

# Kubeconfig
/etc/rancher/rke2/rke2.yaml

# Data directory
/var/lib/rancher/rke2/

# Log directory
/var/log/pods/
```

### D.2 RKE2 Node Commands

```bash
# Check RKE2 service status
systemctl status rke2-server
systemctl status rke2-agent

# Start/Stop/Restart RKE2
systemctl start rke2-server
systemctl stop rke2-server
systemctl restart rke2-server

# View RKE2 logs
journalctl -u rke2-server -f
journalctl -u rke2-server --since "1 hour ago"

# Check RKE2 version
/var/lib/rancher/rke2/bin/rke2 --version

# Use kubectl on nodes
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin
kubectl get nodes
```

### D.3 RKE2 Upgrade Procedure

```bash
# On each node, one at a time:

# 1. Cordon the node
kubectl cordon <node-name>

# 2. Drain the node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 3. SSH to node
ssh root@<node-ip>

# 4. Stop RKE2
systemctl stop rke2-server

# 5. Upgrade RKE2
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.31.0+rke2r1 sh -

# 6. Start RKE2
systemctl start rke2-server

# 7. Verify node is ready
kubectl get nodes

# 8. Uncordon the node
kubectl uncordon <node-name>

# 9. Wait for node to stabilize before proceeding to next
kubectl wait --for=condition=Ready node/<node-name> --timeout=300s
```

### D.4 RKE2 Certificate Rotation

```bash
# RKE2 certificates are stored in:
/var/lib/rancher/rke2/server/tls/

# View certificate expiration
openssl x509 -in /var/lib/rancher/rke2/server/tls/client-admin.crt -noout -dates

# Rotate certificates (RKE2 v1.25+)
systemctl stop rke2-server
rke2 certificate rotate
systemctl start rke2-server

# Regenerate kubeconfig after rotation
cat /etc/rancher/rke2/rke2.yaml
```

### D.5 etcd Management

```bash
# Check etcd health
kubectl -n kube-system exec -it etcd-<node-name> -- \
  etcdctl --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  endpoint health

# Check etcd cluster members
kubectl -n kube-system exec -it etcd-<node-name> -- \
  etcdctl --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  member list

# Defrag etcd
kubectl -n kube-system exec -it etcd-<node-name> -- \
  etcdctl --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  defrag
```

### D.6 etcd Backup and Restore

```bash
# Create etcd snapshot
/var/lib/rancher/rke2/bin/rke2 etcd-snapshot save --name=manual-snapshot

# List snapshots
/var/lib/rancher/rke2/bin/rke2 etcd-snapshot list

# Snapshots are stored in:
/var/lib/rancher/rke2/server/db/snapshots/

# Restore from snapshot (emergency only)
systemctl stop rke2-server
/var/lib/rancher/rke2/bin/rke2 server --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/rke2/server/db/snapshots/<snapshot-name>
systemctl start rke2-server
```

---

## Appendix E: Cost Management with Kubecost

### E.1 Kubecost Dashboard

Access Kubecost at: https://kubecost.aleklab.com

### E.2 Cost Allocation

```bash
# View namespace costs via API
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl 'http://kubecost-cost-analyzer.kubecost.svc:9090/model/allocation?window=7d&aggregate=namespace'
```

### E.3 Cost Reports

```bash
# Get total cluster cost
curl -s 'http://kubecost-cost-analyzer.kubecost.svc:9090/model/allocation?window=30d&aggregate=cluster' | jq

# Get cost by controller
curl -s 'http://kubecost-cost-analyzer.kubecost.svc:9090/model/allocation?window=7d&aggregate=controller' | jq

# Get cost by service
curl -s 'http://kubecost-cost-analyzer.kubecost.svc:9090/model/allocation?window=7d&aggregate=service' | jq
```

### E.4 Cost Optimization Recommendations

```bash
# Check for optimization opportunities
curl -s 'http://kubecost-cost-analyzer.kubecost.svc:9090/model/savings/requestSizing' | jq

# Get idle resource costs
curl -s 'http://kubecost-cost-analyzer.kubecost.svc:9090/model/savings/orphanedResources' | jq
```

### E.5 Setting Cost Alerts

```yaml
# Example cost alert ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubecost-alerts
  namespace: kubecost
data:
  alerts.yaml: |
    alerts:
      - type: budget
        threshold: 100
        window: 7d
        aggregation: namespace
        filter: monitoring
        owner: team-platform
```

---

## Appendix F: Useful PromQL Queries for Mimir

### F.1 Cluster Overview

```promql
# Total CPU cores available
sum(machine_cpu_cores)

# Total memory available (bytes)
sum(machine_memory_bytes)

# Node count
count(kube_node_info)

# Pod count by namespace
count by (namespace) (kube_pod_info)
```

### F.2 Resource Usage

```promql
# CPU usage by namespace (cores)
sum by (namespace) (
  rate(container_cpu_usage_seconds_total{container!="", container!="POD"}[5m])
)

# Memory usage by namespace (bytes)
sum by (namespace) (
  container_memory_usage_bytes{container!="", container!="POD"}
)

# CPU request vs actual usage by deployment
sum by (deployment) (
  kube_pod_container_resource_requests{resource="cpu"}
) 
/ 
sum by (deployment) (
  rate(container_cpu_usage_seconds_total[5m])
)

# Memory request vs actual usage
sum by (namespace) (
  kube_pod_container_resource_requests{resource="memory"}
)
/
sum by (namespace) (
  container_memory_usage_bytes{container!=""}
)
```

### F.3 Pod Health

```promql
# Pods not in Running state
kube_pod_status_phase{phase!~"Running|Succeeded"}

# Container restart count (last hour)
increase(kube_pod_container_status_restarts_total[1h]) > 0

# Pods in CrashLoopBackOff
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}

# OOMKilled containers
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}
```

### F.4 Network

```promql
# Ingress traffic by pod (bytes/sec)
sum by (pod) (rate(container_network_receive_bytes_total[5m]))

# Egress traffic by pod (bytes/sec)
sum by (pod) (rate(container_network_transmit_bytes_total[5m]))

# HTTP request rate by ingress
sum by (ingress) (rate(traefik_service_requests_total[5m]))

# HTTP error rate by ingress
sum by (ingress) (
  rate(traefik_service_requests_total{code=~"5.."}[5m])
) 
/
sum by (ingress) (
  rate(traefik_service_requests_total[5m])
) * 100
```

### F.5 Storage

```promql
# PVC usage percentage
(
  kubelet_volume_stats_used_bytes
  /
  kubelet_volume_stats_capacity_bytes
) * 100

# PVCs near capacity (>80%)
(
  kubelet_volume_stats_used_bytes
  /
  kubelet_volume_stats_capacity_bytes
) * 100 > 80

# Inode usage
(
  kubelet_volume_stats_inodes_used
  /
  kubelet_volume_stats_inodes
) * 100
```

### F.6 Node Resources

```promql
# Node CPU usage percentage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Node disk usage percentage
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100

# Node network traffic
sum by (instance) (rate(node_network_receive_bytes_total[5m]))
sum by (instance) (rate(node_network_transmit_bytes_total[5m]))
```

### F.7 Application Specific

```promql
# ArgoCD sync status
argocd_app_info{sync_status!="Synced"}

# GitLab Sidekiq job queue
sum(gitlab_background_jobs_queue_size)

# Loki ingested bytes
sum(rate(loki_distributor_bytes_received_total[5m]))

# Mimir ingested samples
sum(rate(cortex_distributor_received_samples_total[5m]))
```

---

## Appendix G: Common Automation Scripts

### G.1 Daily Health Check Script

```bash
#!/bin/bash
# daily-health-check.sh

set -e

echo "=== Daily Cluster Health Check ==="
echo "Date: $(date)"
echo ""

echo "## Node Status"
kubectl get nodes -o wide
echo ""

echo "## Pods Not Running"
kubectl get pods -A | grep -v Running | grep -v Completed || echo "All pods running!"
echo ""

echo "## Recent Events (last 30 min)"
kubectl get events -A --sort-by='.lastTimestamp' --field-selector type=Warning | tail -20
echo ""

echo "## ArgoCD Application Status"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
echo ""

echo "## PVC Status"
kubectl get pvc -A | grep -v Bound || echo "All PVCs bound!"
echo ""

echo "## Certificate Status"
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter
echo ""

echo "## Resource Usage (Top 10 pods by memory)"
kubectl top pods -A --sort-by=memory | head -15
echo ""

echo "## Velero Backup Status"
velero backup get | head -10
echo ""

echo "=== Health Check Complete ==="
```

### G.2 Upgrade All Applications Script

```bash
#!/bin/bash
# upgrade-check.sh

APPS_DIR="gitops/apps"

declare -A REPOS=(
  ["grafana"]="grafana/grafana"
  ["mimir"]="grafana/mimir-distributed"
  ["loki"]="grafana/loki"
  ["tempo"]="grafana/tempo"
  ["alloy"]="grafana/alloy"
  ["kyverno"]="kyverno/kyverno"
  ["trivy"]="aquasecurity/trivy-operator"
  ["falco"]="falcosecurity/falco"
  ["velero"]="vmware-tanzu/velero"
)

helm repo update

echo "=== Chart Version Check ==="
echo ""

for app in "${!REPOS[@]}"; do
  chart="${REPOS[$app]}"
  file="$APPS_DIR/${app}.yaml"
  
  if [ -f "$file" ]; then
    current=$(grep "targetRevision:" "$file" | head -1 | awk '{print $2}')
    latest=$(helm search repo "$chart" --versions 2>/dev/null | head -2 | tail -1 | awk '{print $2}')
    
    if [ "$current" != "$latest" ]; then
      echo "⚠️  $app: $current → $latest"
    else
      echo "✅ $app: $current (up to date)"
    fi
  fi
done
```

### G.3 Pre-Upgrade Backup Script

```bash
#!/bin/bash
# pre-upgrade-backup.sh

NAMESPACE=$1
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

if [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <namespace>"
  exit 1
fi

echo "Creating backup for namespace: $NAMESPACE"

velero backup create pre-upgrade-${NAMESPACE}-${TIMESTAMP} \
  --include-namespaces $NAMESPACE \
  --wait

echo "Backup completed. Verify:"
velero backup describe pre-upgrade-${NAMESPACE}-${TIMESTAMP}
```

### G.4 Monitoring Dashboard Export

```bash
#!/bin/bash
# export-dashboards.sh

OUTPUT_DIR="./exported-dashboards"
mkdir -p "$OUTPUT_DIR"

# Get all dashboard ConfigMaps
DASHBOARDS=$(kubectl get configmaps -n monitoring -l grafana_dashboard=1 -o name)

for dashboard in $DASHBOARDS; do
  name=$(echo $dashboard | sed 's|configmap/||')
  echo "Exporting: $name"
  kubectl get $dashboard -n monitoring -o jsonpath='{.data}' | jq -r 'to_entries[0].value' > "$OUTPUT_DIR/${name}.json"
done

echo "Exported $(echo "$DASHBOARDS" | wc -l | tr -d ' ') dashboards to $OUTPUT_DIR"
```

### G.5 Cleanup Old Backups

```bash
#!/bin/bash
# cleanup-old-backups.sh

RETENTION_DAYS=30

echo "Finding backups older than $RETENTION_DAYS days..."

OLD_BACKUPS=$(velero backup get -o json | jq -r --arg days "$RETENTION_DAYS" \
  '.items[] | select((now - (.metadata.creationTimestamp | fromdateiso8601)) / 86400 > ($days | tonumber)) | .metadata.name')

if [ -z "$OLD_BACKUPS" ]; then
  echo "No old backups found."
  exit 0
fi

echo "Found backups to delete:"
echo "$OLD_BACKUPS"
echo ""

read -p "Delete these backups? (y/N) " confirm
if [ "$confirm" = "y" ]; then
  for backup in $OLD_BACKUPS; do
    echo "Deleting: $backup"
    velero backup delete $backup --confirm
  done
  echo "Cleanup complete."
else
  echo "Cancelled."
fi
```

### G.6 GitOps Sync Status Monitor

```bash
#!/bin/bash
# watch-sync.sh

while true; do
  clear
  echo "=== ArgoCD Application Sync Status ==="
  echo "Updated: $(date)"
  echo ""
  
  kubectl get applications -n argocd -o custom-columns=\
'NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,MESSAGE:.status.conditions[0].message' \
  --sort-by=.status.health.status
  
  echo ""
  echo "Press Ctrl+C to exit"
  sleep 10
done
```

### G.7 Generate Kubeconfig for Service Account

```bash
#!/bin/bash
# create-kubeconfig.sh

SA_NAME=$1
NAMESPACE=$2

if [ -z "$SA_NAME" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <service-account-name> <namespace>"
  exit 1
fi

# Create service account
kubectl create serviceaccount $SA_NAME -n $NAMESPACE

# Create token secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SA_NAME}-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: $SA_NAME
type: kubernetes.io/service-account-token
EOF

# Wait for token
sleep 2

# Get values
TOKEN=$(kubectl get secret ${SA_NAME}-token -n $NAMESPACE -o jsonpath='{.data.token}' | base64 -d)
CA=$(kubectl get secret ${SA_NAME}-token -n $NAMESPACE -o jsonpath='{.data.ca\.crt}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

# Generate kubeconfig
cat <<EOF > kubeconfig-${SA_NAME}.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA
    server: $SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SA_NAME
    namespace: $NAMESPACE
  name: ${SA_NAME}@${CLUSTER_NAME}
current-context: ${SA_NAME}@${CLUSTER_NAME}
users:
- name: $SA_NAME
  user:
    token: $TOKEN
EOF

echo "Kubeconfig saved to: kubeconfig-${SA_NAME}.yaml"
```

### G.8 Resource Quota Check

```bash
#!/bin/bash
# check-quotas.sh

echo "=== Resource Quota Status ==="
echo ""

for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  quota=$(kubectl get resourcequota -n $ns -o json 2>/dev/null | jq -r '.items[0].status // empty')
  
  if [ -n "$quota" ]; then
    echo "Namespace: $ns"
    echo "$quota" | jq -r 'to_entries[] | "  \(.key): \(.value.used // "0") / \(.value.hard // "∞")"'
    echo ""
  fi
done
```

---

## Appendix H: Migration Guides

### H.1 Migrating Applications Between Clusters

```bash
#!/bin/bash
# migrate-app.sh

SOURCE_CONTEXT=$1
DEST_CONTEXT=$2  
NAMESPACE=$3

if [ -z "$SOURCE_CONTEXT" ] || [ -z "$DEST_CONTEXT" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <source-context> <destination-context> <namespace>"
  exit 1
fi

echo "=== Migrating $NAMESPACE from $SOURCE_CONTEXT to $DEST_CONTEXT ==="

# Step 1: Create backup on source
echo "Step 1: Creating backup on source cluster..."
kubectl config use-context $SOURCE_CONTEXT
velero backup create migration-${NAMESPACE}-$(date +%Y%m%d) \
  --include-namespaces $NAMESPACE \
  --wait

# Step 2: Export manifests
echo "Step 2: Exporting manifests..."
mkdir -p ./migration-${NAMESPACE}
kubectl get all,configmaps,secrets,pvc -n $NAMESPACE -o yaml > ./migration-${NAMESPACE}/all-resources.yaml

# Step 3: Switch to destination
echo "Step 3: Switching to destination cluster..."
kubectl config use-context $DEST_CONTEXT

# Step 4: Create namespace
echo "Step 4: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Apply resources (review first!)
echo "Step 5: Resources exported to ./migration-${NAMESPACE}/"
echo "Review and apply with: kubectl apply -f ./migration-${NAMESPACE}/"
```

### H.2 Migrating from docker-compose to Kubernetes

```bash
# Convert docker-compose to Kubernetes manifests
# Using kompose tool

# Install kompose
curl -L https://github.com/kubernetes/kompose/releases/download/v1.31.2/kompose-linux-amd64 -o kompose
chmod +x kompose
sudo mv kompose /usr/local/bin/

# Convert docker-compose.yml
kompose convert -f docker-compose.yml -o ./k8s-manifests/

# Review and modify generated manifests
ls ./k8s-manifests/

# Apply to cluster
kubectl apply -f ./k8s-manifests/
```

### H.3 Migrating Persistent Volumes

```bash
# For ReadWriteOnce volumes, use Velero
velero backup create pv-migration \
  --include-namespaces my-namespace \
  --include-resources pv,pvc

velero restore create --from-backup pv-migration

# For live migration without downtime
# (requires ReadWriteMany or application support)

# 1. Create new PVC
kubectl apply -f new-pvc.yaml

# 2. Create migration pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pv-migrator
spec:
  containers:
  - name: migrator
    image: alpine
    command: ["/bin/sh", "-c", "cp -av /source/* /dest/ && sleep infinity"]
    volumeMounts:
    - name: source
      mountPath: /source
    - name: dest
      mountPath: /dest
  volumes:
  - name: source
    persistentVolumeClaim:
      claimName: old-pvc
  - name: dest
    persistentVolumeClaim:
      claimName: new-pvc
EOF

# 3. Verify migration
kubectl exec pv-migrator -- ls -la /dest

# 4. Update application to use new PVC
# 5. Delete old PVC and migrator pod
```

---

## Appendix I: Performance Tuning

### I.1 Node sysctl Settings

Applied via sysctl-tuner DaemonSet:

```yaml
# gitops/apps/sysctl-tuner-manifests/daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: sysctl-tuner
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: sysctl-tuner
  template:
    metadata:
      labels:
        app: sysctl-tuner
    spec:
      hostPID: true
      hostNetwork: true
      initContainers:
        - name: sysctl
          image: busybox
          securityContext:
            privileged: true
          command:
            - /bin/sh
            - -c
            - |
              sysctl -w fs.inotify.max_user_watches=524288
              sysctl -w fs.inotify.max_user_instances=8192
              sysctl -w fs.file-max=2097152
              sysctl -w net.core.somaxconn=65535
              sysctl -w net.ipv4.tcp_max_syn_backlog=65535
      containers:
        - name: pause
          image: k8s.gcr.io/pause:3.9
```

### I.2 Application Resource Tuning

```yaml
# High-performance application settings
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 4000m
    memory: 8Gi

# JVM applications
env:
  - name: JAVA_OPTS
    value: "-Xms2g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Go applications
env:
  - name: GOGC
    value: "100"
  - name: GOMAXPROCS
    value: "4"
```

### I.3 Ingress Performance

```yaml
# Traefik performance tuning
deployment:
  kind: DaemonSet
  
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

# Enable compression
additionalArguments:
  - "--entryPoints.websecure.http.middlewares=compress@file"
  
# Connection pooling
serversTransport:
  maxIdleConnsPerHost: 200
```

### I.4 Database Performance

```yaml
# PostgreSQL tuning for GitLab
postgresql:
  primary:
    extendedConfiguration: |
      max_connections = 200
      shared_buffers = 1GB
      effective_cache_size = 3GB
      maintenance_work_mem = 256MB
      checkpoint_completion_target = 0.9
      wal_buffers = 16MB
      default_statistics_target = 100
      random_page_cost = 1.1
      effective_io_concurrency = 200
      work_mem = 5242kB
      min_wal_size = 1GB
      max_wal_size = 4GB
```

---

## Appendix J: Compliance & Audit

### J.1 Audit Logging

```bash
# View Kubernetes audit logs (on nodes)
ssh root@<node-ip>
journalctl -u rke2-server | grep audit

# Enable detailed audit logging in RKE2
# Add to /etc/rancher/rke2/config.yaml:
# kube-apiserver-arg:
#   - "audit-log-path=/var/log/kubernetes/audit.log"
#   - "audit-log-maxage=30"
#   - "audit-log-maxbackup=10"
#   - "audit-log-maxsize=100"
#   - "audit-policy-file=/etc/rancher/rke2/audit-policy.yaml"
```

### J.2 Compliance Checks

```bash
# Run Trivy compliance scan
kubectl get clustercompliancereports -o json | jq '.items[].report'

# Check CIS benchmark results
kubectl get configauditreports -A -o json | jq '.items[] | {name: .metadata.name, critical: .report.summary.criticalCount, high: .report.summary.highCount}'
```

### J.3 RBAC Audit

```bash
# List all ClusterRoleBindings
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name

# Check who can do what
kubectl auth can-i --list --as=system:serviceaccount:default:default

# Find overly permissive roles
kubectl get clusterroles -o json | jq '.items[] | select(.rules[].verbs[] == "*" and .rules[].resources[] == "*") | .metadata.name'
```

### J.4 Network Policy Audit

```bash
# List all network policies
kubectl get networkpolicies -A -o yaml

# Find namespaces without network policies
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  count=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  if [ "$count" -eq "0" ]; then
    echo "No NetworkPolicy in: $ns"
  fi
done
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-12-20 | DevOps Team | Initial comprehensive manual |

---

**End of Document**

*For questions or updates, contact the Platform Engineering team.*

---

## Appendix K: Glossary of Terms

| Term | Definition |
|------|------------|
| **ArgoCD** | GitOps continuous delivery tool for Kubernetes |
| **Alloy** | Grafana's unified telemetry collector (formerly Grafana Agent) |
| **CCM** | Cloud Controller Manager - integrates with cloud provider APIs |
| **CRD** | Custom Resource Definition - extends Kubernetes API |
| **CSI** | Container Storage Interface - standard for storage drivers |
| **DaemonSet** | Ensures a pod runs on all (or selected) nodes |
| **etcd** | Distributed key-value store for Kubernetes state |
| **GitOps** | Managing infrastructure via Git as single source of truth |
| **Helm** | Kubernetes package manager using charts |
| **HPA** | Horizontal Pod Autoscaler - scales pods based on metrics |
| **Ingress** | Manages external access to services (HTTP/HTTPS) |
| **Istio** | Service mesh providing mTLS, traffic management, observability |
| **KEDA** | Kubernetes Event-Driven Autoscaling |
| **Kyverno** | Kubernetes-native policy engine |
| **Loki** | Log aggregation system from Grafana |
| **Mimir** | Long-term metrics storage backend (Prometheus-compatible) |
| **mTLS** | Mutual TLS - both client and server authenticate |
| **OTLP** | OpenTelemetry Protocol for traces/metrics/logs |
| **PV** | Persistent Volume - cluster storage resource |
| **PVC** | Persistent Volume Claim - request for storage |
| **RBAC** | Role-Based Access Control |
| **RKE2** | Rancher Kubernetes Engine 2 - hardened Kubernetes distribution |
| **StatefulSet** | Manages stateful applications with stable identities |
| **Tempo** | Distributed tracing backend from Grafana |
| **Terraform** | Infrastructure as Code tool from HashiCorp |
| **Traefik** | Cloud-native ingress controller and reverse proxy |
| **Velero** | Kubernetes backup and disaster recovery tool |
| **VPA** | Vertical Pod Autoscaler - adjusts pod resource requests |

---

## Appendix L: Keyboard Shortcuts & CLI Tips

### L.1 kubectl Aliases

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgn='kubectl get namespaces'
alias kga='kubectl get all'
alias kgpa='kubectl get pods -A'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kdel='kubectl delete'
alias kaf='kubectl apply -f'

# Context and namespace
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# Handy functions
kgpn() { kubectl get pods -n "$1"; }
kln() { kubectl logs -n "$1" "$2" --tail=100; }

# Watch pods
alias kwp='kubectl get pods -w'
alias kwpa='kubectl get pods -A -w'
```

### L.2 kubectl Context Management

```bash
# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# Set default namespace for context
kubectl config set-context --current --namespace=monitoring

# View current context
kubectl config current-context
```

### L.3 kubectl Output Formats

```bash
# JSON output
kubectl get pods -o json

# YAML output
kubectl get pods -o yaml

# Wide output (more columns)
kubectl get pods -o wide

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# JSONPath
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Go template
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
```

### L.4 Helm Tips

```bash
# See what would be installed
helm template <release> <chart> --values values.yaml

# Debug helm installation
helm install <release> <chart> --dry-run --debug

# Get values from installed release
helm get values <release> -n <namespace>

# Get all information about a release
helm get all <release> -n <namespace>

# Rollback to previous version
helm rollback <release> <revision> -n <namespace>
```

### L.5 ArgoCD CLI Tips

```bash
# Login
argocd login <server> --username admin

# Sync with prune
argocd app sync <app> --prune

# Force sync without cache
argocd app sync <app> --force --replace

# Wait for app to be healthy
argocd app wait <app> --health

# List all applications
argocd app list -o wide

# Get application details
argocd app get <app> --show-operation
```

### L.6 Velero CLI Tips

```bash
# Create backup with TTL
velero backup create <name> --ttl 720h

# Describe restore with details
velero restore describe <name> --details

# Download backup
velero backup download <name>

# View schedule details
velero schedule describe <schedule-name>
```

---

## Appendix M: Contact & Support

### M.1 Internal Resources

| Resource | Purpose | Access |
|----------|---------|--------|
| Rancher UI | Cluster management | https://kube.aleklab.com |
| ArgoCD UI | GitOps deployments | https://argo.aleklab.com |
| Grafana | Observability | https://grafana.aleklab.com |
| GitLab | Source code & CI | https://gitlab.aleklab.com |

### M.2 Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Platform Lead | platform-lead@aleklab.com | 24/7 |
| On-Call | pagerduty.aleklab.com | 24/7 |
| Cloud Provider | Hetzner Support | support@hetzner.com |

### M.3 Escalation Path

1. **L1 - Self-Service**: Check this manual and troubleshoot.md
2. **L2 - Team Lead**: Escalate to platform team
3. **L3 - Architecture**: Major infrastructure decisions
4. **L4 - Vendor**: Cloud provider or tool vendor support

### M.4 Useful External Links

| Resource | URL |
|----------|-----|
| Kubernetes Docs | https://kubernetes.io/docs/ |
| RKE2 Docs | https://docs.rke2.io/ |
| ArgoCD Docs | https://argo-cd.readthedocs.io/ |
| Grafana Docs | https://grafana.com/docs/ |
| Velero Docs | https://velero.io/docs/ |
| Istio Docs | https://istio.io/latest/docs/ |
| Terraform Registry | https://registry.terraform.io/ |
| Helm Hub | https://artifacthub.io/ |

---

## Index

**A**
- Alloy configuration: §6.3.5, §11
- ArgoCD: §5, §6, Appendix L
- Autoscaling: §17

**B**
- Backup: §13
- Best practices: §22

**C**
- Certificates: §19.3, §21.4
- Cloud-init: §4
- Cloudflare: §4, §19
- Compliance: Appendix J
- Crossplane: §6.3.16, §10
- Cost management: Appendix E

**D**
- DNS: §19
- Disaster recovery: §13

**E**
- etcd: Appendix D.5, D.6
- ExternalDNS: §6.3.15, §19.2
- External Secrets: §6.3.14, §14

**F**
- Falco: §6.3.8, §12.4

**G**
- GitLab: §6.3.11, §16
- GitOps: §5
- Grafana: §6.3.1, §11

**H**
- Hetzner: §4, §8, §18

**I**
- Istio: §6.3.9, §15

**K**
- KEDA: §6.3.12, §17.1
- Kubecost: §6.3.18, Appendix E
- Kyverno: §6.3.6, §12.1

**L**
- Loki: §6.3.3, §11
- Load balancer: §1.4

**M**
- Migration: Appendix H
- Mimir: §6.3.2, §11, Appendix F
- MLflow: §6.3.19
- Monitoring: §11

**N**
- Network: §19
- Node management: Appendix D

**O**
- OpenBao: §6.3.17, §14

**P**
- Performance tuning: Appendix I
- PromQL: Appendix F
- Provisioning: §8

**R**
- Rancher: §7, §9, §10
- RKE2: Appendix D
- Runbooks: §21

**S**
- Scripts: Appendix G
- Security: §12
- Secrets: §14
- Storage: §18

**T**
- Tempo: §6.3.4
- Terraform: §4, §9
- Traefik: §19.1
- Trivy: §6.3.7, §12.3
- Troubleshooting: §20

**U**
- Updates: §6
- Upgrade procedures: §6, Appendix D.3

**V**
- Velero: §6.3.10, §13
- VPA: §6.3.13, §17.3

---

**THE END**

