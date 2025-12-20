# Crossplane Operations Manual

> **Complete Guide for Infrastructure-as-Code with Crossplane**
> For the Hetzner-Rancher Kubernetes Stack

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Installation & Configuration](#3-installation--configuration)
4. [Provider Management](#4-provider-management)
5. [Composite Resources (XRDs)](#5-composite-resources-xrds)
6. [Compositions](#6-compositions)
7. [Claims](#7-claims)
8. [Managing Cloud Resources](#8-managing-cloud-resources)
9. [Hetzner Cloud Provider](#9-hetzner-cloud-provider)
10. [AWS Provider](#10-aws-provider)
11. [Cloudflare Provider](#11-cloudflare-provider)
12. [Kubernetes Provider](#12-kubernetes-provider)
13. [Composition Functions](#13-composition-functions)
14. [Troubleshooting](#14-troubleshooting)
15. [Best Practices](#15-best-practices)
16. [Reference](#16-reference)

---

## 1. Overview

### 1.1 What is Crossplane?

Crossplane is an open-source Kubernetes add-on that transforms your cluster into a **universal control plane**. It enables you to:

- **Provision and manage cloud infrastructure** using Kubernetes-native APIs
- **Create custom APIs** (called Composite Resources) that abstract complex infrastructure
- **Enable self-service** for developers while maintaining platform team control
- **Manage multi-cloud resources** from a single control plane

### 1.2 Crossplane in This Stack

In the Hetzner-Rancher infrastructure, Crossplane is deployed via ArgoCD and provides:

| Capability | Description |
|------------|-------------|
| Infrastructure Provisioning | Create Hetzner, AWS, or any cloud resources |
| Custom Abstractions | Define platform-specific resource types |
| Cluster Management | Provision and manage additional Kubernetes clusters |
| Integration with Rancher | Import/manage clusters via Rancher API |

### 1.3 Current Configuration

```yaml
# gitops/apps/crossplane.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane
  namespace: argocd
spec:
  source:
    repoURL: https://charts.crossplane.io/stable
    targetRevision: 2.1.3
    chart: crossplane
```

---

## 2. Architecture

### 2.1 Crossplane Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Crossplane Architecture                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Crossplane Core                               │   │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌────────────────────┐   │   │
│  │  │ Crossplane  │  │      RBAC       │  │    Composition     │   │   │
│  │  │ Controller  │  │     Manager     │  │     Functions      │   │   │
│  │  └─────────────┘  └─────────────────┘  └────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        Providers                                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────────┐   │   │
│  │  │ Hetzner  │  │   AWS    │  │Cloudflare│  │   Kubernetes    │   │   │
│  │  │ Provider │  │ Provider │  │ Provider │  │    Provider     │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Managed Resources                             │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────────┐   │   │
│  │  │  Server  │  │   S3     │  │   DNS    │  │    Namespace    │   │   │
│  │  │ (Hcloud) │  │ (AWS)    │  │  Record  │  │   (K8s)         │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Resource Hierarchy

```
CompositeResourceDefinition (XRD)
    │
    ├── Defines the API schema for a custom resource
    │
    ▼
Composition
    │
    ├── Defines how to satisfy XRD requirements
    ├── Maps inputs to provider resources
    │
    ▼
Claim (XRC)
    │
    ├── User-facing request for a composite resource
    ├── Namespace-scoped (for developers)
    │
    ▼
Managed Resources
    │
    └── Actual cloud resources (servers, buckets, etc.)
```

---

## 3. Installation & Configuration

### 3.1 Verify Installation

```bash
# Check Crossplane pods
kubectl get pods -n crossplane-system

# Expected output:
# crossplane-xxxxxx-xxxxx          1/1     Running
# crossplane-rbac-manager-xxxxxx   1/1     Running

# Check Crossplane version
kubectl get deployment crossplane -n crossplane-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 3.2 Check CRDs

```bash
# List Crossplane CRDs
kubectl get crds | grep crossplane

# Expected CRDs:
# compositeresourcedefinitions.apiextensions.crossplane.io
# compositions.apiextensions.crossplane.io
# configurationrevisions.pkg.crossplane.io
# configurations.pkg.crossplane.io
# controllerconfigs.pkg.crossplane.io
# deploymentruntimeconfigs.pkg.crossplane.io
# environmentconfigs.apiextensions.crossplane.io
# functions.pkg.crossplane.io
# functionrevisions.pkg.crossplane.io
# locks.pkg.crossplane.io
# providerconfigs.*.crossplane.io
# providerrevisions.pkg.crossplane.io
# providers.pkg.crossplane.io
# storeconfigs.secrets.crossplane.io
# usages.apiextensions.crossplane.io
```

### 3.3 Update Crossplane

```bash
# Check current version
kubectl get deployment crossplane -n crossplane-system -o jsonpath='{.spec.template.spec.containers[0].image}'

# Update via GitOps
# Edit gitops/apps/crossplane.yaml, change targetRevision
# Commit and push

# Verify update
helm search repo crossplane-stable/crossplane --versions | head -5
```

---

## 4. Provider Management

### 4.1 List Installed Providers

```bash
# List all providers
kubectl get providers

# Get provider details
kubectl describe provider <provider-name>

# Check provider status
kubectl get providers -o custom-columns=NAME:.metadata.name,HEALTHY:.status.conditions[0].status,REVISION:.status.currentRevision
```

### 4.2 Install a Provider

```yaml
# provider-hetzner.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-hetzner
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-hcloud:v0.2.0
  controllerConfigRef:
    name: provider-hetzner-config
---
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  name: provider-hetzner-config
spec:
  resources:
    limits:
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

```bash
# Apply provider
kubectl apply -f provider-hetzner.yaml

# Wait for provider to be ready
kubectl wait --for=condition=Healthy provider/provider-hetzner --timeout=300s
```

### 4.3 Configure Provider Credentials

```yaml
# provider-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-credentials
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    {
      "token": "your-hetzner-api-token"
    }
---
apiVersion: hcloud.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: hcloud-credentials
      key: credentials
```

```bash
# Apply credentials (use kubectl create secret for sensitive data)
kubectl create secret generic hcloud-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"token":"'$HCLOUD_TOKEN'"}'

kubectl apply -f provider-config.yaml
```

### 4.4 Update Provider

```bash
# Check available versions
kubectl get provider provider-hetzner -o yaml | grep package

# Update provider spec
kubectl patch provider provider-hetzner --type merge \
  -p '{"spec":{"package":"xpkg.upbound.io/crossplane-contrib/provider-hcloud:v0.3.0"}}'

# Monitor rollout
kubectl get providerrevisions -w
```

---

## 5. Composite Resources (XRDs)

### 5.1 Understanding XRDs

CompositeResourceDefinitions (XRDs) define custom APIs that abstract infrastructure:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.platform.aleklab.com
spec:
  group: platform.aleklab.com
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
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
                size:
                  type: string
                  enum: [small, medium, large]
                  default: small
                engine:
                  type: string
                  enum: [postgres, mysql]
                  default: postgres
              required:
                - size
            status:
              type: object
              properties:
                connectionString:
                  type: string
                host:
                  type: string
                port:
                  type: integer
```

### 5.2 Create an XRD

```bash
# Create XRD file
cat <<EOF > xrd-database.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.platform.aleklab.com
spec:
  group: platform.aleklab.com
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
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
                size:
                  type: string
                  enum: [small, medium, large]
                environment:
                  type: string
                  enum: [dev, staging, prod]
              required:
                - size
                - environment
EOF

# Apply XRD
kubectl apply -f xrd-database.yaml

# Verify XRD
kubectl get xrds
kubectl describe xrd xdatabases.platform.aleklab.com
```

### 5.3 List XRDs

```bash
# List all XRDs
kubectl get compositeresourcedefinitions

# Short alias
kubectl get xrds

# Get XRD details
kubectl get xrd <name> -o yaml
```

---

## 6. Compositions

### 6.1 Understanding Compositions

Compositions define how to fulfill an XRD by mapping inputs to managed resources:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-postgres-hetzner
  labels:
    provider: hetzner
    engine: postgres
spec:
  compositeTypeRef:
    apiVersion: platform.aleklab.com/v1alpha1
    kind: XDatabase
  
  resources:
    - name: namespace
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Namespace
              metadata:
                name: "" # patched
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.manifest.metadata.name
          transforms:
            - type: string
              string:
                fmt: "db-%s"
    
    - name: postgres
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: postgres
              spec:
                replicas: 1
                selector:
                  matchLabels:
                    app: postgres
                template:
                  metadata:
                    labels:
                      app: postgres
                  spec:
                    containers:
                      - name: postgres
                        image: postgres:15
                        resources:
                          requests:
                            cpu: 100m
                            memory: 256Mi
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.manifest.metadata.namespace
          transforms:
            - type: string
              string:
                fmt: "db-%s"
        - type: FromCompositeFieldPath
          fromFieldPath: spec.size
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].resources.requests.memory
          transforms:
            - type: map
              map:
                small: 256Mi
                medium: 512Mi
                large: 1Gi
```

### 6.2 Create a Composition

```bash
# Create composition file
cat <<EOF > composition-database.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-postgres-dev
  labels:
    environment: dev
spec:
  compositeTypeRef:
    apiVersion: platform.aleklab.com/v1alpha1
    kind: XDatabase
  
  resources:
    - name: configmap
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: db-config
              data:
                DATABASE_HOST: localhost
                DATABASE_PORT: "5432"
      patches:
        - fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.manifest.metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-config"
EOF

kubectl apply -f composition-database.yaml
```

### 6.3 Composition Selection

Multiple Compositions can satisfy an XRD. Selection is based on:

```yaml
# In the Claim or Composite Resource
spec:
  compositionSelector:
    matchLabels:
      environment: prod
      provider: aws

# Or specify directly
spec:
  compositionRef:
    name: database-postgres-aws-prod
```

---

## 7. Claims

### 7.1 Understanding Claims

Claims are namespace-scoped requests for composite resources, designed for developers:

```yaml
apiVersion: platform.aleklab.com/v1alpha1
kind: Database
metadata:
  name: my-app-db
  namespace: my-team
spec:
  size: medium
  environment: dev
  compositionSelector:
    matchLabels:
      environment: dev
```

### 7.2 Create a Claim

```bash
# Create claim
cat <<EOF | kubectl apply -f -
apiVersion: platform.aleklab.com/v1alpha1
kind: Database
metadata:
  name: my-database
  namespace: default
spec:
  size: small
  environment: dev
EOF

# Check claim status
kubectl get databases
kubectl describe database my-database
```

### 7.3 Monitor Claim Resources

```bash
# Get composite resource created by claim
kubectl get xdatabases

# Get managed resources created by composition
kubectl get managed

# Watch all resources
kubectl get claim,composite,managed -A -w
```

### 7.4 Delete a Claim

```bash
# Delete claim (also deletes composite and managed resources)
kubectl delete database my-database

# Verify cleanup
kubectl get xdatabases
kubectl get managed
```

---

## 8. Managing Cloud Resources

### 8.1 View All Managed Resources

```bash
# List all managed resources
kubectl get managed

# Filter by provider
kubectl get managed -o json | jq -r '.items[] | select(.apiVersion | contains("hcloud")) | .metadata.name'

# Check resource status
kubectl get managed -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,SYNCED:.status.conditions[1].status
```

### 8.2 Debug Managed Resources

```bash
# Describe managed resource
kubectl describe <resource-type> <name>

# Check events
kubectl get events --field-selector involvedObject.name=<resource-name>

# View provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-hetzner
```

### 8.3 Manual Managed Resource

```yaml
# Create a Hetzner server directly (without composition)
apiVersion: server.hcloud.crossplane.io/v1alpha1
kind: Server
metadata:
  name: test-server
spec:
  forProvider:
    name: test-server
    serverType: cx11
    image: ubuntu-22.04
    location: hel1
    sshKeys:
      - your-ssh-key
  providerConfigRef:
    name: default
```

---

## 9. Hetzner Cloud Provider

### 9.1 Install Hetzner Provider

```yaml
# provider-hetzner.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-hcloud
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-hcloud:v0.2.0
```

```bash
kubectl apply -f provider-hetzner.yaml
kubectl wait --for=condition=Healthy provider/provider-hcloud --timeout=300s
```

### 9.2 Configure Hetzner Provider

```bash
# Create secret
kubectl create secret generic hcloud-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"token":"'$HCLOUD_TOKEN'"}'

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: hcloud.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: hcloud-credentials
      key: credentials
EOF
```

### 9.3 Hetzner Resource Examples

#### Create Server
```yaml
apiVersion: server.hcloud.crossplane.io/v1alpha1
kind: Server
metadata:
  name: my-server
spec:
  forProvider:
    name: my-server
    serverType: cx21
    image: ubuntu-24.04
    location: hel1
    sshKeys:
      - my-ssh-key
    labels:
      environment: dev
  providerConfigRef:
    name: default
```

#### Create Volume
```yaml
apiVersion: volume.hcloud.crossplane.io/v1alpha1
kind: Volume
metadata:
  name: my-volume
spec:
  forProvider:
    name: my-volume
    size: 50
    location: hel1
    format: ext4
  providerConfigRef:
    name: default
```

#### Create Network
```yaml
apiVersion: network.hcloud.crossplane.io/v1alpha1
kind: Network
metadata:
  name: my-network
spec:
  forProvider:
    name: my-network
    ipRange: 10.0.0.0/16
  providerConfigRef:
    name: default
```

---

## 10. AWS Provider

### 10.1 Install AWS Provider

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1.0.0
```

### 10.2 Configure AWS Provider

```bash
# Create AWS credentials secret
kubectl create secret generic aws-credentials \
  -n crossplane-system \
  --from-literal=creds="[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY"

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: creds
EOF
```

### 10.3 AWS Resource Examples

#### S3 Bucket
```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-bucket
spec:
  forProvider:
    region: eu-central-1
    tags:
      Environment: dev
  providerConfigRef:
    name: default
```

#### RDS Instance
```yaml
apiVersion: rds.aws.upbound.io/v1beta1
kind: Instance
metadata:
  name: my-postgres
spec:
  forProvider:
    region: eu-central-1
    engine: postgres
    engineVersion: "15"
    instanceClass: db.t3.micro
    allocatedStorage: 20
    username: admin
    passwordSecretRef:
      name: db-password
      namespace: crossplane-system
      key: password
    skipFinalSnapshot: true
  providerConfigRef:
    name: default
```

---

## 11. Cloudflare Provider

### 11.1 Install Cloudflare Provider

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-cloudflare
spec:
  package: xpkg.upbound.io/upbound/provider-cloudflare:v0.1.0
```

### 11.2 Configure Cloudflare Provider

```bash
# Create Cloudflare credentials
kubectl create secret generic cloudflare-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"api_token":"'$CLOUDFLARE_API_TOKEN'"}'

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: cloudflare.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: cloudflare-credentials
      key: credentials
EOF
```

### 11.3 Cloudflare Resource Examples

#### DNS Record
```yaml
apiVersion: dns.cloudflare.upbound.io/v1alpha1
kind: Record
metadata:
  name: app-dns
spec:
  forProvider:
    zoneIdSelector:
      matchLabels:
        zone: aleklab.com
    name: app
    type: A
    value: 1.2.3.4
    ttl: 300
    proxied: false
  providerConfigRef:
    name: default
```

---

## 12. Kubernetes Provider

### 12.1 Install Kubernetes Provider

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
```

### 12.2 Configure Kubernetes Provider

```yaml
# Use in-cluster config
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
```

### 12.3 Kubernetes Resource Examples

#### Create Namespace
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: dev-namespace
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: development
        labels:
          environment: dev
  providerConfigRef:
    name: default
```

#### Create ConfigMap
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: app-config
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: app-config
        namespace: development
      data:
        APP_ENV: development
        LOG_LEVEL: debug
  providerConfigRef:
    name: default
```

---

## 13. Composition Functions

### 13.1 Overview

Composition Functions enable complex logic in compositions using code:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-with-functions
spec:
  compositeTypeRef:
    apiVersion: platform.aleklab.com/v1alpha1
    kind: XDatabase
  
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: database
            base:
              apiVersion: rds.aws.crossplane.io/v1beta1
              kind: DBInstance
              spec:
                forProvider:
                  engine: postgres
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.size
                toFieldPath: spec.forProvider.instanceClass
                transforms:
                  - type: map
                    map:
                      small: db.t3.micro
                      medium: db.t3.small
                      large: db.t3.medium
```

### 13.2 Install Composition Functions

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.3.0
```

### 13.3 Available Functions

| Function | Purpose |
|----------|---------|
| function-patch-and-transform | Standard patching logic |
| function-go-templating | Go template rendering |
| function-auto-ready | Auto-set composite readiness |
| function-kcl | KCL language support |

---

## 14. Troubleshooting

### 14.1 Common Issues

#### Provider Not Ready
```bash
# Check provider status
kubectl describe provider <provider-name>

# Check provider pod logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=<provider-name>

# Common causes:
# - Invalid credentials
# - Network connectivity
# - Rate limiting
```

#### Resource Not Syncing
```bash
# Check resource conditions
kubectl describe <resource-type> <resource-name>

# Check events
kubectl get events --field-selector involvedObject.name=<resource-name>

# Common causes:
# - Provider errors
# - Invalid configuration
# - Permission issues
```

#### Composition Not Working
```bash
# Check XRD status
kubectl describe xrd <xrd-name>

# Check composite resource
kubectl describe <composite-kind> <name>

# Check claim
kubectl describe <claim-kind> <name> -n <namespace>

# Common causes:
# - Schema mismatch
# - Invalid patches
# - Missing composition
```

### 14.2 Debug Commands

```bash
# View all Crossplane resources
kubectl get crossplane

# View Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane

# View RBAC manager logs
kubectl logs -n crossplane-system deployment/crossplane-rbac-manager

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-hcloud --tail=100

# Force reconciliation
kubectl annotate <resource-type> <name> crossplane.io/reconcile-request=$(date +%s)
```

### 14.3 Health Checks

```bash
#!/bin/bash
# crossplane-health.sh

echo "=== Crossplane Health Check ==="

echo -e "\n## Core Components"
kubectl get pods -n crossplane-system

echo -e "\n## Providers"
kubectl get providers -o custom-columns=NAME:.metadata.name,HEALTHY:.status.conditions[0].status

echo -e "\n## XRDs"
kubectl get xrds -o custom-columns=NAME:.metadata.name,ESTABLISHED:.status.conditions[0].status

echo -e "\n## Compositions"
kubectl get compositions

echo -e "\n## Managed Resources"
kubectl get managed -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,SYNCED:.status.conditions[1].status
```

---

## 15. Best Practices

### 15.1 XRD Design

1. **Keep APIs simple** - Hide complexity from consumers
2. **Use enums** - Constrain input values
3. **Version your APIs** - Use v1alpha1, v1beta1, v1
4. **Add status fields** - Expose useful information

### 15.2 Composition Design

1. **One composition per environment** - dev, staging, prod
2. **Use labels for selection** - Enable composition selection
3. **Test compositions** - Verify before production
4. **Use composition functions** - For complex logic

### 15.3 Security

1. **Least privilege** - Minimal provider permissions
2. **Secrets management** - Use External Secrets
3. **RBAC** - Limit who can create claims
4. **Audit** - Log resource changes

### 15.4 Naming Conventions

| Resource | Convention | Example |
|----------|------------|---------|
| XRD | x<resources>.domain | xdatabases.platform.aleklab.com |
| Composition | <kind>-<provider>-<env> | database-aws-prod |
| Claim | <app>-<resource> | myapp-database |
| Provider | provider-<cloud> | provider-aws |

---

## 16. Reference

### 16.1 Useful Commands

```bash
# Crossplane
kubectl get crossplane
kubectl api-resources | grep crossplane

# Providers
kubectl get providers
kubectl get providerrevisions
kubectl get providerconfigs

# Resources
kubectl get xrds
kubectl get compositions
kubectl get claims -A
kubectl get composite
kubectl get managed

# Debug
kubectl describe provider <name>
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=<provider>
```

### 16.2 Documentation Links

| Resource | URL |
|----------|-----|
| Crossplane Docs | https://docs.crossplane.io/ |
| Upbound Marketplace | https://marketplace.upbound.io/ |
| Crossplane GitHub | https://github.com/crossplane/crossplane |

### 16.3 Provider Packages

| Provider | Package |
|----------|---------|
| AWS | xpkg.upbound.io/upbound/provider-aws:vX.X.X |
| GCP | xpkg.upbound.io/upbound/provider-gcp:vX.X.X |
| Azure | xpkg.upbound.io/upbound/provider-azure:vX.X.X |
| Kubernetes | xpkg.upbound.io/crossplane-contrib/provider-kubernetes:vX.X.X |
| Helm | xpkg.upbound.io/crossplane-contrib/provider-helm:vX.X.X |
| Terraform | xpkg.upbound.io/upbound/provider-terraform:vX.X.X |

---

**End of Crossplane Documentation**
