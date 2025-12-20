# Kratix Platform Engineering Manual

> **Building Internal Developer Platforms with Kratix and Crossplane**
> For the Hetzner-Rancher Kubernetes Stack

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Installation](#3-installation)
4. [Core Concepts](#4-core-concepts)
5. [Promises](#5-promises)
6. [Workflows & Pipelines](#6-workflows--pipelines)
7. [State Stores](#7-state-stores)
8. [Destinations (Worker Clusters)](#8-destinations-worker-clusters)
9. [Kratix + Crossplane Integration](#9-kratix--crossplane-integration)
10. [Building Platform Promises](#10-building-platform-promises)
11. [Database Promise Example](#11-database-promise-example)
12. [Kubernetes Namespace Promise](#12-kubernetes-namespace-promise)
13. [Application Environment Promise](#13-application-environment-promise)
14. [Consuming Promises](#14-consuming-promises)
15. [Multi-Cluster Operations](#15-multi-cluster-operations)
16. [Observability & Monitoring](#16-observability--monitoring)
17. [Troubleshooting](#17-troubleshooting)
18. [Best Practices](#18-best-practices)
19. [Reference](#19-reference)

---

## 1. Overview

### 1.1 What is Kratix?

Kratix is an open-source **platform engineering framework** that enables teams to build Internal Developer Platforms (IDPs) on Kubernetes. It provides:

| Feature | Description |
|---------|-------------|
| **Promises** | Declarative templates defining platform services |
| **Workflows** | Customizable pipelines for resource provisioning |
| **Multi-cluster** | Separate platform cluster from worker clusters |
| **Everything-as-a-Service** | Enable self-service for any capability |

### 1.2 Kratix vs Crossplane

| Aspect | Kratix | Crossplane |
|--------|--------|------------|
| **Focus** | Platform orchestration | Infrastructure management |
| **APIs** | Promises (custom workflows) | XRDs (compositions) |
| **Execution** | Pipeline containers | Provider controllers |
| **Multi-cluster** | Native support | Requires configuration |
| **Best Use** | Orchestrating multiple tools | Managing cloud resources |

### 1.3 Why Kratix + Crossplane?

Together, Kratix and Crossplane create a powerful platform:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Internal Developer Platform                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Developer Request                                                       │
│       │                                                                  │
│       ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                         KRATIX                                   │    │
│  │  ┌─────────────┐    ┌─────────────────┐    ┌────────────────┐   │    │
│  │  │   Promise   │───▶│    Pipeline     │───▶│  State Store   │   │    │
│  │  │   (API)     │    │  (Validation,   │    │  (GitOps)      │   │    │
│  │  │             │    │   Transform)    │    │                │   │    │
│  │  └─────────────┘    └─────────────────┘    └───────┬────────┘   │    │
│  └────────────────────────────────────────────────────┼────────────┘    │
│                                                       │                  │
│                                                       ▼                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                       CROSSPLANE                                 │    │
│  │  ┌─────────────┐    ┌─────────────────┐    ┌────────────────┐   │    │
│  │  │    Claim    │───▶│   Composition   │───▶│    Managed     │   │    │
│  │  │             │    │                 │    │   Resources    │   │    │
│  │  └─────────────┘    └─────────────────┘    └────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│                                   │                                      │
│                                   ▼                                      │
│                          ┌────────────────┐                              │
│                          │  Cloud Resources│                             │
│                          │  (Hetzner, AWS) │                             │
│                          └────────────────┘                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.4 Integration with This Stack

In the Hetzner-Rancher infrastructure:

- **Platform Cluster**: RKE2 cluster running Kratix and Crossplane
- **Worker Clusters**: Provisioned via Terraform/Rancher
- **State Store**: Git repository (GitLab) or MinIO (S3-compatible)
- **GitOps**: ArgoCD for reconciliation

---

## 2. Architecture

### 2.1 Platform Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PLATFORM CLUSTER (RKE2)                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                         Kratix                                    │   │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌────────────────────┐   │   │
│  │  │   Kratix    │  │   Promise       │  │   Work Scheduler   │   │   │
│  │  │ Controller  │  │   Controller    │  │                    │   │   │
│  │  └─────────────┘  └─────────────────┘  └────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                       Crossplane                                  │   │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌────────────────────┐   │   │
│  │  │  Provider   │  │    Provider     │  │    Provider        │   │   │
│  │  │  Hetzner    │  │      AWS        │  │   Kubernetes       │   │   │
│  │  └─────────────┘  └─────────────────┘  └────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    Supporting Services                            │   │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌────────────────────┐   │   │
│  │  │   ArgoCD    │  │   Cert-Manager  │  │     GitLab         │   │   │
│  │  └─────────────┘  └─────────────────┘  └────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
              │                               │
              ▼                               ▼
     ┌────────────────┐              ┌────────────────┐
     │ Worker Cluster │              │ Worker Cluster │
     │     Dev        │              │     Prod       │
     └────────────────┘              └────────────────┘
```

### 2.2 Request Flow

```
1. Developer submits Resource Request
       │
       ▼
2. Kratix validates request against Promise API
       │
       ▼
3. Pipeline runs (containers in sequence)
   - Validate inputs
   - Apply policies
   - Generate Crossplane Claims
   - Generate Kubernetes manifests
       │
       ▼
4. Output written to State Store
       │
       ▼
5. ArgoCD/Flux syncs to Worker Cluster
       │
       ▼
6. Crossplane provisions cloud resources
       │
       ▼
7. Developer receives provisioned resources
```

---

## 3. Installation

### 3.1 Prerequisites

- Kubernetes cluster (RKE2) with kubectl access
- Cert-Manager installed
- Crossplane installed (from gitops/apps/crossplane.yaml)
- State Store (Git repo or S3 bucket)

### 3.2 Install Kratix

```bash
# Install Kratix CRDs and controllers
kubectl apply --filename https://github.com/syntasso/kratix/releases/latest/download/kratix.yaml

# Verify installation
kubectl get pods -n kratix-platform-system

# Expected output:
# kratix-platform-controller-manager-xxxxx   1/1     Running
```

### 3.3 ArgoCD Application for Kratix

```yaml
# gitops/apps/kratix.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kratix
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: default
  source:
    repoURL: https://github.com/syntasso/kratix
    targetRevision: v0.17.0
    path: distribution/kratix
  destination:
    server: https://kubernetes.default.svc
    namespace: kratix-platform-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```bash
# Apply via GitOps
kubectl apply -f gitops/apps/kratix.yaml

# Or apply directly
kubectl apply -f https://github.com/syntasso/kratix/releases/download/v0.17.0/kratix.yaml
```

### 3.4 Verify Installation

```bash
# Check Kratix CRDs
kubectl get crds | grep kratix

# Expected:
# destinations.platform.kratix.io
# gitstatestores.platform.kratix.io
# bucketstatestores.platform.kratix.io
# promises.platform.kratix.io
# works.platform.kratix.io
# workplacements.platform.kratix.io

# Check controllers
kubectl get deployment -n kratix-platform-system
```

---

## 4. Core Concepts

### 4.1 Promises

A **Promise** is a contract between platform team and users:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: database
spec:
  # API definition for users
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: databases.platform.example.com
    spec:
      group: platform.example.com
      names:
        kind: Database
        plural: databases
      scope: Namespaced
      versions:
        - name: v1
          served: true
          storage: true
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
  
  # Workflows to execute
  workflows:
    resource:
      configure:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: configure-database
          spec:
            containers:
              - name: configure
                image: ghcr.io/myorg/database-pipeline:v1
```

### 4.2 Resources

A **Resource** is a user request for a Promise:

```yaml
apiVersion: platform.example.com/v1
kind: Database
metadata:
  name: my-database
  namespace: team-alpha
spec:
  size: medium
```

### 4.3 Pipelines

**Pipelines** are workflows executed for Promise or Resource lifecycle:

```yaml
workflows:
  promise:
    configure:  # Runs when Promise is applied
      - apiVersion: platform.kratix.io/v1alpha1
        kind: Pipeline
        metadata:
          name: setup-dependencies
        spec:
          containers:
            - name: install-crds
              image: bitnami/kubectl:latest
  
  resource:
    configure:  # Runs when Resource is created/updated
      - apiVersion: platform.kratix.io/v1alpha1
        kind: Pipeline
        metadata:
          name: provision-resource
        spec:
          containers:
            - name: generate-manifests
              image: myorg/generator:v1
    
    delete:     # Runs when Resource is deleted
      - apiVersion: platform.kratix.io/v1alpha1
        kind: Pipeline
        metadata:
          name: cleanup-resource
        spec:
          containers:
            - name: cleanup
              image: myorg/cleaner:v1
```

### 4.4 State Stores

**State Stores** are where pipeline outputs are written:

```yaml
# Git State Store
apiVersion: platform.kratix.io/v1alpha1
kind: GitStateStore
metadata:
  name: default
spec:
  url: https://gitlab.aleklab.com/platform/gitops.git
  branch: main
  authSecretRef:
    name: git-credentials
    namespace: kratix-platform-system

# S3/MinIO State Store
apiVersion: platform.kratix.io/v1alpha1
kind: BucketStateStore
metadata:
  name: minio-store
spec:
  endpoint: minio.velero.svc.cluster.local:9000
  bucketName: kratix-state
  insecure: true
  authSecretRef:
    name: minio-credentials
    namespace: kratix-platform-system
```

### 4.5 Destinations

**Destinations** are clusters where resources are scheduled:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-dev
  labels:
    environment: dev
spec:
  stateStoreRef:
    name: default
    kind: GitStateStore
  path: clusters/dev
```

---

## 5. Promises

### 5.1 Promise Structure

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: <promise-name>
  labels:
    <key>: <value>
spec:
  # Define the API users will interact with
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    # ... CRD spec
  
  # Dependencies installed with Promise
  dependencies:
    - apiVersion: apps/v1
      kind: Deployment
      # ...
  
  # Where resources should be scheduled
  destinationSelectors:
    - matchLabels:
        environment: prod
  
  # Workflows for Promise and Resource lifecycle
  workflows:
    promise:
      configure: [...]
      delete: [...]
    resource:
      configure: [...]
      delete: [...]
```

### 5.2 Install a Promise

```bash
# Apply Promise
kubectl apply -f database-promise.yaml

# Verify Promise is installed
kubectl get promises
kubectl describe promise database

# Check the CRD was created
kubectl get crds | grep database
```

### 5.3 List Promises

```bash
# List all Promises
kubectl get promises

# Get Promise details
kubectl get promise database -o yaml

# Check Promise status
kubectl describe promise database
```

### 5.4 Update a Promise

```bash
# Edit Promise
kubectl edit promise database

# Or apply updated manifest
kubectl apply -f updated-database-promise.yaml

# Promise workflows will re-run
```

### 5.5 Delete a Promise

```bash
# Delete Promise (also deletes associated Resources)
kubectl delete promise database

# Verify cleanup
kubectl get databases -A
kubectl get crds | grep database
```

---

## 6. Workflows & Pipelines

### 6.1 Pipeline Container Structure

Pipeline containers receive inputs and produce outputs:

```
/kratix/input/     # Input files
  └── object.yaml  # The Resource that triggered pipeline

/kratix/output/    # Output files (scheduled to Destinations)
  └── *.yaml       # Generated manifests

/kratix/metadata/  # Metadata files
  └── status.yaml  # Status updates for Resource
  └── destination-selectors.yaml  # Override destination selection
```

### 6.2 Simple Pipeline Container

```dockerfile
# Dockerfile
FROM alpine:3.18

COPY pipeline.sh /pipeline.sh
RUN chmod +x /pipeline.sh

CMD ["/pipeline.sh"]
```

```bash
#!/bin/bash
# pipeline.sh

# Read input resource
NAME=$(yq eval '.metadata.name' /kratix/input/object.yaml)
SIZE=$(yq eval '.spec.size' /kratix/input/object.yaml)

# Generate output manifests
cat <<EOF > /kratix/output/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: db-${NAME}
  labels:
    managed-by: kratix
EOF

cat <<EOF > /kratix/output/crossplane-claim.yaml
apiVersion: platform.aleklab.com/v1alpha1
kind: Database
metadata:
  name: ${NAME}
  namespace: db-${NAME}
spec:
  size: ${SIZE}
  compositionSelector:
    matchLabels:
      provider: hetzner
EOF

# Update status
cat <<EOF > /kratix/metadata/status.yaml
message: "Database ${NAME} provisioning started"
connectionString: "postgres://db-${NAME}.svc:5432"
EOF
```

### 6.3 Multi-Container Pipeline

```yaml
workflows:
  resource:
    configure:
      - apiVersion: platform.kratix.io/v1alpha1
        kind: Pipeline
        metadata:
          name: configure-database
        spec:
          containers:
            # Step 1: Validate inputs
            - name: validate
              image: myorg/validator:v1
              env:
                - name: REQUIRED_FIELDS
                  value: "size,environment"
            
            # Step 2: Apply policies
            - name: policy-check
              image: myorg/opa-check:v1
              env:
                - name: POLICY_URL
                  value: "http://opa.policy.svc/v1/data/database"
            
            # Step 3: Generate Crossplane Claims
            - name: generate
              image: myorg/generator:v1
            
            # Step 4: Add labels/annotations
            - name: labeler
              image: myorg/labeler:v1
              env:
                - name: LABELS
                  value: "team=platform,managed-by=kratix"
```

### 6.4 Pipeline with Secrets

```yaml
spec:
  containers:
    - name: configure
      image: myorg/pipeline:v1
      env:
        - name: CLOUD_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloud-credentials
              key: token
      volumeMounts:
        - name: creds
          mountPath: /credentials
          readOnly: true
  volumes:
    - name: creds
      secret:
        secretName: cloud-credentials
```

---

## 7. State Stores

### 7.1 Git State Store

Configure GitLab as state store:

```yaml
# Create Git credentials secret
apiVersion: v1
kind: Secret
metadata:
  name: git-credentials
  namespace: kratix-platform-system
type: Opaque
stringData:
  username: kratix-bot
  password: glpat-xxxxxxxxxxxxxxxxxxxx
---
apiVersion: platform.kratix.io/v1alpha1
kind: GitStateStore
metadata:
  name: default
spec:
  url: https://gitlab.aleklab.com/platform/kratix-state.git
  branch: main
  authSecretRef:
    name: git-credentials
    namespace: kratix-platform-system
```

### 7.2 S3/MinIO State Store

Use embedded MinIO from Velero:

```yaml
# Create MinIO credentials secret
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: kratix-platform-system
type: Opaque
stringData:
  accessKeyID: minioadmin
  secretAccessKey: minioadmin
---
apiVersion: platform.kratix.io/v1alpha1
kind: BucketStateStore
metadata:
  name: minio-store
spec:
  endpoint: velero-minio.velero.svc.cluster.local:9000
  bucketName: kratix
  insecure: true
  authSecretRef:
    name: minio-credentials
    namespace: kratix-platform-system
```

### 7.3 Verify State Store

```bash
# Check state store status
kubectl get gitstatestores
kubectl get bucketstatestores

# Describe for details
kubectl describe gitstatestore default
```

---

## 8. Destinations (Worker Clusters)

### 8.1 Register a Destination

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-dev
  labels:
    environment: dev
    region: europe
spec:
  stateStoreRef:
    name: default
    kind: GitStateStore
  path: clusters/worker-dev
```

### 8.2 Register Multiple Destinations

```yaml
# Development cluster
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-dev
  labels:
    environment: dev
spec:
  stateStoreRef:
    name: default
    kind: GitStateStore
  path: clusters/dev
---
# Staging cluster
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-staging
  labels:
    environment: staging
spec:
  stateStoreRef:
    name: default
    kind: GitStateStore
  path: clusters/staging
---
# Production cluster
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-prod
  labels:
    environment: prod
    critical: "true"
spec:
  stateStoreRef:
    name: default
    kind: GitStateStore
  path: clusters/prod
```

### 8.3 In-Cluster Destination

For single-cluster setup:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: platform-cluster
  labels:
    environment: platform
spec:
  stateStoreRef:
    name: default
    kind: GitStateStore
  path: platform
```

### 8.4 Configure ArgoCD for Destinations

Each destination path needs ArgoCD Application:

```yaml
# gitops/apps/kratix-destination-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kratix-destination-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.aleklab.com/platform/kratix-state.git
    targetRevision: main
    path: clusters/dev
  destination:
    server: https://dev-cluster-api:6443
    namespace: '*'
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 9. Kratix + Crossplane Integration

### 9.1 Integration Pattern

Kratix pipelines generate Crossplane Claims:

```
Developer Request → Kratix Promise
                        │
                        ▼
              Kratix Pipeline
              (validation, policy)
                        │
                        ▼
            Generate Crossplane Claim
                        │
                        ▼
              Write to State Store
                        │
                        ▼
               ArgoCD Syncs
                        │
                        ▼
        Crossplane Provisions Resources
```

### 9.2 Pipeline Generating Crossplane Claim

```bash
#!/bin/bash
# pipeline.sh - Generate Crossplane Claim

# Read input
NAME=$(yq '.metadata.name' /kratix/input/object.yaml)
NAMESPACE=$(yq '.metadata.namespace' /kratix/input/object.yaml)
SIZE=$(yq '.spec.size' /kratix/input/object.yaml)
ENVIRONMENT=$(yq '.spec.environment' /kratix/input/object.yaml)

# Map size to Crossplane spec
case $SIZE in
  small)  INSTANCE_CLASS="db.t3.micro" ;;
  medium) INSTANCE_CLASS="db.t3.small" ;;
  large)  INSTANCE_CLASS="db.t3.medium" ;;
esac

# Generate Crossplane Claim
cat <<EOF > /kratix/output/crossplane-claim.yaml
apiVersion: platform.aleklab.com/v1alpha1
kind: Database
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
  labels:
    kratix-promise: database
    environment: ${ENVIRONMENT}
spec:
  size: ${SIZE}
  compositionSelector:
    matchLabels:
      environment: ${ENVIRONMENT}
      provider: hetzner
  writeConnectionSecretToRef:
    name: ${NAME}-connection
    namespace: ${NAMESPACE}
EOF

# Set status
cat <<EOF > /kratix/metadata/status.yaml
phase: Provisioning
message: "Crossplane claim created, waiting for provisioning"
EOF
```

### 9.3 Promise with Crossplane Dependencies

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: database
spec:
  # Install Crossplane XRD and Composition with Promise
  dependencies:
    # XRD
    - apiVersion: apiextensions.crossplane.io/v1
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
    
    # Composition
    - apiVersion: apiextensions.crossplane.io/v1
      kind: Composition
      metadata:
        name: database-hetzner
        labels:
          provider: hetzner
      spec:
        compositeTypeRef:
          apiVersion: platform.aleklab.com/v1alpha1
          kind: XDatabase
        resources:
          # ... composition resources
  
  # Kratix API
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: databaserequests.platform.kratix.io
    spec:
      group: platform.kratix.io
      names:
        kind: DatabaseRequest
        plural: databaserequests
      scope: Namespaced
      versions:
        - name: v1alpha1
          served: true
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    name:
                      type: string
                    size:
                      type: string
                      enum: [small, medium, large]
                    environment:
                      type: string
                      enum: [dev, staging, prod]
```

---

## 10. Building Platform Promises

### 10.1 Promise Development Workflow

```bash
# 1. Define the API
# What inputs do developers need to provide?

# 2. Design the pipeline
# What validations, transformations are needed?

# 3. Define outputs
# What Kubernetes/Crossplane resources are created?

# 4. Test locally
kratix test promise --promise-file=promise.yaml --input=sample-request.yaml

# 5. Install Promise
kubectl apply -f promise.yaml

# 6. Test end-to-end
kubectl apply -f sample-request.yaml
kubectl get <resource-kind> -w
```

### 10.2 Promise Template

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: ${PROMISE_NAME}
  labels:
    team: platform
spec:
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: ${PLURAL}.platform.aleklab.com
    spec:
      group: platform.aleklab.com
      names:
        kind: ${KIND}
        plural: ${PLURAL}
        singular: ${SINGULAR}
      scope: Namespaced
      versions:
        - name: v1alpha1
          served: true
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    # Define your spec here
                  required: []
          additionalPrinterColumns:
            - name: Status
              type: string
              jsonPath: .status.message
  
  destinationSelectors:
    - matchLabels:
        environment: platform
  
  workflows:
    resource:
      configure:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: configure-${PROMISE_NAME}
          spec:
            containers:
              - name: configure
                image: ${PIPELINE_IMAGE}
```

### 10.3 Pipeline Image Best Practices

```dockerfile
# Dockerfile for pipeline image
FROM alpine:3.18

# Install tools
RUN apk add --no-cache \
    bash \
    curl \
    yq \
    jq \
    kubectl

# Copy pipeline scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Default command
CMD ["/scripts/configure.sh"]
```

---

## 11. Database Promise Example

### 11.1 Complete Database Promise

```yaml
# database-promise.yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: database
  labels:
    category: data
spec:
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: databases.platform.aleklab.com
    spec:
      group: platform.aleklab.com
      names:
        kind: Database
        plural: databases
        singular: database
        shortNames:
          - db
      scope: Namespaced
      versions:
        - name: v1alpha1
          served: true
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    name:
                      type: string
                      description: "Database name"
                    engine:
                      type: string
                      enum: [postgres, mysql]
                      default: postgres
                    version:
                      type: string
                      default: "15"
                    size:
                      type: string
                      enum: [small, medium, large]
                      default: small
                    environment:
                      type: string
                      enum: [dev, staging, prod]
                  required:
                    - name
                    - environment
                status:
                  type: object
                  properties:
                    phase:
                      type: string
                    message:
                      type: string
                    connectionString:
                      type: string
          additionalPrinterColumns:
            - name: Engine
              type: string
              jsonPath: .spec.engine
            - name: Size
              type: string
              jsonPath: .spec.size
            - name: Status
              type: string
              jsonPath: .status.phase
  
  destinationSelectors:
    - matchLabels:
        environment: platform
  
  workflows:
    resource:
      configure:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: configure-database
          spec:
            containers:
              - name: validate
                image: ghcr.io/syntasso/kratix-pipeline-utility:v0.1.0
                command: ["/bin/sh"]
                args:
                  - -c
                  - |
                    #!/bin/sh
                    set -e
                    
                    NAME=$(yq '.spec.name' /kratix/input/object.yaml)
                    ENV=$(yq '.spec.environment' /kratix/input/object.yaml)
                    SIZE=$(yq '.spec.size' /kratix/input/object.yaml)
                    ENGINE=$(yq '.spec.engine' /kratix/input/object.yaml)
                    
                    # Validate prod requires medium or large
                    if [ "$ENV" = "prod" ] && [ "$SIZE" = "small" ]; then
                      echo "ERROR: Production requires medium or large size"
                      exit 1
                    fi
                    
                    echo "Validation passed for $NAME ($ENGINE, $SIZE, $ENV)"
              
              - name: generate
                image: ghcr.io/syntasso/kratix-pipeline-utility:v0.1.0
                command: ["/bin/sh"]
                args:
                  - -c
                  - |
                    #!/bin/sh
                    set -e
                    
                    NAME=$(yq '.spec.name' /kratix/input/object.yaml)
                    NAMESPACE=$(yq '.metadata.namespace' /kratix/input/object.yaml)
                    ENV=$(yq '.spec.environment' /kratix/input/object.yaml)
                    SIZE=$(yq '.spec.size' /kratix/input/object.yaml)
                    ENGINE=$(yq '.spec.engine' /kratix/input/object.yaml)
                    VERSION=$(yq '.spec.version' /kratix/input/object.yaml)
                    
                    # Generate Crossplane Claim
                    cat <<EOF > /kratix/output/crossplane-claim.yaml
                    apiVersion: platform.aleklab.com/v1alpha1
                    kind: XDatabase
                    metadata:
                      name: ${NAME}
                      labels:
                        kratix-promise: database
                        environment: ${ENV}
                    spec:
                      engine: ${ENGINE}
                      version: "${VERSION}"
                      size: ${SIZE}
                      compositionSelector:
                        matchLabels:
                          environment: ${ENV}
                    EOF
                    
                    # Generate namespace if needed
                    cat <<EOF > /kratix/output/namespace.yaml
                    apiVersion: v1
                    kind: Namespace
                    metadata:
                      name: db-${NAME}
                      labels:
                        managed-by: kratix
                        database: ${NAME}
                    EOF
                    
                    # Set status
                    cat <<EOF > /kratix/metadata/status.yaml
                    phase: Provisioning
                    message: "Database ${NAME} is being provisioned"
                    connectionString: "postgresql://${NAME}:5432/db-${NAME}"
                    EOF
      
      delete:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: delete-database
          spec:
            containers:
              - name: cleanup
                image: ghcr.io/syntasso/kratix-pipeline-utility:v0.1.0
                command: ["/bin/sh"]
                args:
                  - -c
                  - |
                    #!/bin/sh
                    echo "Cleanup triggered for database"
                    # Crossplane will handle actual deletion
```

### 11.2 Install Database Promise

```bash
# Apply Promise
kubectl apply -f database-promise.yaml

# Verify
kubectl get promises
kubectl get crds | grep database
```

### 11.3 Request a Database

```yaml
# my-database.yaml
apiVersion: platform.aleklab.com/v1alpha1
kind: Database
metadata:
  name: myapp-db
  namespace: team-alpha
spec:
  name: myapp-db
  engine: postgres
  version: "15"
  size: medium
  environment: dev
```

```bash
kubectl apply -f my-database.yaml
kubectl get databases -n team-alpha -w
```

---

## 12. Kubernetes Namespace Promise

### 12.1 Team Namespace Promise

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: team-namespace
spec:
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: teamnamespaces.platform.aleklab.com
    spec:
      group: platform.aleklab.com
      names:
        kind: TeamNamespace
        plural: teamnamespaces
      scope: Cluster
      versions:
        - name: v1alpha1
          served: true
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    teamName:
                      type: string
                    environment:
                      type: string
                      enum: [dev, staging, prod]
                    resourceQuota:
                      type: string
                      enum: [small, medium, large]
                      default: small
                    enableIstio:
                      type: boolean
                      default: false
                  required:
                    - teamName
                    - environment
  
  workflows:
    resource:
      configure:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: create-namespace
          spec:
            containers:
              - name: generate
                image: ghcr.io/syntasso/kratix-pipeline-utility:v0.1.0
                command: ["/bin/sh"]
                args:
                  - -c
                  - |
                    #!/bin/sh
                    set -e
                    
                    TEAM=$(yq '.spec.teamName' /kratix/input/object.yaml)
                    ENV=$(yq '.spec.environment' /kratix/input/object.yaml)
                    QUOTA=$(yq '.spec.resourceQuota' /kratix/input/object.yaml)
                    ISTIO=$(yq '.spec.enableIstio' /kratix/input/object.yaml)
                    
                    NS_NAME="${TEAM}-${ENV}"
                    
                    # Namespace
                    cat <<EOF > /kratix/output/namespace.yaml
                    apiVersion: v1
                    kind: Namespace
                    metadata:
                      name: ${NS_NAME}
                      labels:
                        team: ${TEAM}
                        environment: ${ENV}
                        managed-by: kratix
                    EOF
                    
                    # Add Istio label if enabled
                    if [ "$ISTIO" = "true" ]; then
                      yq -i '.metadata.labels["istio-injection"] = "enabled"' /kratix/output/namespace.yaml
                    fi
                    
                    # Resource Quota
                    case $QUOTA in
                      small)  CPU="2"; MEM="4Gi" ;;
                      medium) CPU="4"; MEM="8Gi" ;;
                      large)  CPU="8"; MEM="16Gi" ;;
                    esac
                    
                    cat <<EOF > /kratix/output/quota.yaml
                    apiVersion: v1
                    kind: ResourceQuota
                    metadata:
                      name: ${NS_NAME}-quota
                      namespace: ${NS_NAME}
                    spec:
                      hard:
                        requests.cpu: "${CPU}"
                        requests.memory: "${MEM}"
                        limits.cpu: "$((CPU * 2))"
                        limits.memory: "$((${MEM%Gi} * 2))Gi"
                    EOF
                    
                    # Network Policy (default deny)
                    cat <<EOF > /kratix/output/network-policy.yaml
                    apiVersion: networking.k8s.io/v1
                    kind: NetworkPolicy
                    metadata:
                      name: default-deny
                      namespace: ${NS_NAME}
                    spec:
                      podSelector: {}
                      policyTypes:
                        - Ingress
                        - Egress
                    EOF
```

---

## 13. Application Environment Promise

### 13.1 Full Application Environment

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: app-environment
spec:
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: appenvironments.platform.aleklab.com
    spec:
      group: platform.aleklab.com
      names:
        kind: AppEnvironment
        plural: appenvironments
      scope: Namespaced
      versions:
        - name: v1alpha1
          served: true
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    appName:
                      type: string
                    team:
                      type: string
                    environment:
                      type: string
                      enum: [dev, staging, prod]
                    components:
                      type: object
                      properties:
                        database:
                          type: boolean
                          default: false
                        redis:
                          type: boolean
                          default: false
                        s3Bucket:
                          type: boolean
                          default: false
                        ingress:
                          type: boolean
                          default: true
                  required:
                    - appName
                    - team
                    - environment
  
  workflows:
    resource:
      configure:
        - apiVersion: platform.kratix.io/v1alpha1
          kind: Pipeline
          metadata:
            name: create-app-env
          spec:
            containers:
              - name: generate
                image: ghcr.io/syntasso/kratix-pipeline-utility:v0.1.0
                command: ["/bin/sh"]
                args:
                  - -c
                  - |
                    #!/bin/sh
                    set -e
                    
                    APP=$(yq '.spec.appName' /kratix/input/object.yaml)
                    TEAM=$(yq '.spec.team' /kratix/input/object.yaml)
                    ENV=$(yq '.spec.environment' /kratix/input/object.yaml)
                    
                    NEED_DB=$(yq '.spec.components.database' /kratix/input/object.yaml)
                    NEED_REDIS=$(yq '.spec.components.redis' /kratix/input/object.yaml)
                    NEED_S3=$(yq '.spec.components.s3Bucket' /kratix/input/object.yaml)
                    NEED_INGRESS=$(yq '.spec.components.ingress' /kratix/input/object.yaml)
                    
                    NS="${APP}-${ENV}"
                    
                    # Base namespace
                    cat <<EOF > /kratix/output/00-namespace.yaml
                    apiVersion: v1
                    kind: Namespace
                    metadata:
                      name: ${NS}
                      labels:
                        app: ${APP}
                        team: ${TEAM}
                        environment: ${ENV}
                    EOF
                    
                    # Database (Crossplane Claim)
                    if [ "$NEED_DB" = "true" ]; then
                      cat <<EOF > /kratix/output/01-database.yaml
                    apiVersion: platform.aleklab.com/v1alpha1
                    kind: Database
                    metadata:
                      name: ${APP}-db
                      namespace: ${NS}
                    spec:
                      size: $([ "$ENV" = "prod" ] && echo "medium" || echo "small")
                      compositionSelector:
                        matchLabels:
                          environment: ${ENV}
                    EOF
                    fi
                    
                    # Redis
                    if [ "$NEED_REDIS" = "true" ]; then
                      cat <<EOF > /kratix/output/02-redis.yaml
                    apiVersion: apps/v1
                    kind: Deployment
                    metadata:
                      name: ${APP}-redis
                      namespace: ${NS}
                    spec:
                      replicas: 1
                      selector:
                        matchLabels:
                          app: redis
                      template:
                        metadata:
                          labels:
                            app: redis
                        spec:
                          containers:
                            - name: redis
                              image: redis:7-alpine
                              ports:
                                - containerPort: 6379
                    ---
                    apiVersion: v1
                    kind: Service
                    metadata:
                      name: ${APP}-redis
                      namespace: ${NS}
                    spec:
                      selector:
                        app: redis
                      ports:
                        - port: 6379
                    EOF
                    fi
                    
                    # Ingress
                    if [ "$NEED_INGRESS" = "true" ]; then
                      cat <<EOF > /kratix/output/03-ingress.yaml
                    apiVersion: networking.k8s.io/v1
                    kind: Ingress
                    metadata:
                      name: ${APP}
                      namespace: ${NS}
                      annotations:
                        cert-manager.io/cluster-issuer: letsencrypt-prod
                    spec:
                      ingressClassName: traefik
                      tls:
                        - hosts:
                            - ${APP}.aleklab.com
                          secretName: ${APP}-tls
                      rules:
                        - host: ${APP}.aleklab.com
                          http:
                            paths:
                              - path: /
                                pathType: Prefix
                                backend:
                                  service:
                                    name: ${APP}
                                    port:
                                      number: 80
                    EOF
                    fi
```

---

## 14. Consuming Promises

### 14.1 Developer Workflow

```bash
# 1. List available Promises
kubectl get promises

# 2. View Promise details
kubectl describe promise database

# 3. Check the API schema
kubectl explain databases.platform.aleklab.com

# 4. Create a resource request
kubectl apply -f my-request.yaml

# 5. Check status
kubectl get databases -w

# 6. View details
kubectl describe database my-database
```

### 14.2 Example Requests

```yaml
# Request a database
apiVersion: platform.aleklab.com/v1alpha1
kind: Database
metadata:
  name: orders-db
  namespace: ecommerce
spec:
  name: orders
  engine: postgres
  size: medium
  environment: prod
---
# Request a namespace
apiVersion: platform.aleklab.com/v1alpha1
kind: TeamNamespace
metadata:
  name: team-frontend-dev
spec:
  teamName: frontend
  environment: dev
  resourceQuota: medium
  enableIstio: true
---
# Request full app environment
apiVersion: platform.aleklab.com/v1alpha1
kind: AppEnvironment
metadata:
  name: checkout-service
  namespace: default
spec:
  appName: checkout
  team: payments
  environment: staging
  components:
    database: true
    redis: true
    ingress: true
```

### 14.3 Checking Resource Status

```bash
# Get all resources from a Promise
kubectl get databases -A
kubectl get teamnamespaces
kubectl get appenvironments -A

# Check specific resource
kubectl describe database orders-db -n ecommerce

# Check underlying Crossplane resources
kubectl get managed | grep orders

# Check pipeline runs
kubectl get works -n kratix-platform-system
```

---

## 15. Multi-Cluster Operations

### 15.1 Destination Scheduling

```yaml
# Promise with destination selection
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: database
spec:
  # Schedule to matching destinations
  destinationSelectors:
    - matchLabels:
        hasDatabase: "true"
  
  # ... rest of Promise
```

### 15.2 Per-Resource Destination Override

```yaml
# In pipeline, override destination
cat <<EOF > /kratix/metadata/destination-selectors.yaml
- matchLabels:
    environment: $(yq '.spec.environment' /kratix/input/object.yaml)
EOF
```

### 15.3 Multi-Cluster ArgoCD Setup

```yaml
# For each destination, create ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kratix-destinations
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            kratix-destination: "true"
  template:
    metadata:
      name: 'kratix-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://gitlab.aleklab.com/platform/kratix-state.git
        targetRevision: main
        path: 'clusters/{{name}}'
      destination:
        server: '{{server}}'
        namespace: '*'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## 16. Observability & Monitoring

### 16.1 Kratix Metrics

```yaml
# ServiceMonitor for Kratix
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kratix-controller
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kratix
  namespaceSelector:
    matchNames:
      - kratix-platform-system
  endpoints:
    - port: metrics
      interval: 30s
```

### 16.2 Grafana Dashboard Queries

```promql
# Promise count
count(kratix_promise_info)

# Resources per Promise
count by (promise) (kratix_resource_info)

# Pipeline execution time
histogram_quantile(0.95, kratix_pipeline_duration_seconds_bucket)

# Failed pipelines
sum(rate(kratix_pipeline_errors_total[5m])) by (promise)
```

### 16.3 Logging

```bash
# Kratix controller logs
kubectl logs -n kratix-platform-system deployment/kratix-platform-controller-manager -f

# Pipeline pod logs
kubectl logs -n kratix-platform-system -l kratix.io/pipeline=true --tail=100

# Work scheduler logs
kubectl logs -n kratix-platform-system deployment/kratix-work-scheduler -f
```

---

## 17. Troubleshooting

### 17.1 Common Issues

#### Promise Not Creating CRD
```bash
# Check Promise status
kubectl describe promise <name>

# Look for errors
kubectl get events -n kratix-platform-system

# Check controller logs
kubectl logs -n kratix-platform-system deployment/kratix-platform-controller-manager
```

#### Pipeline Failing
```bash
# Find the Work resource
kubectl get works -n kratix-platform-system

# Check Work status
kubectl describe work <work-name> -n kratix-platform-system

# Check pipeline pod logs
kubectl logs -n kratix-platform-system -l kratix.io/work=<work-name>
```

#### Resources Not Appearing on Destination
```bash
# Check state store content
# For Git: check repository
# For S3: check bucket

# Verify destination registration
kubectl describe destination <name>

# Check ArgoCD sync status
argocd app get kratix-<destination>
```

### 17.2 Debug Commands

```bash
# View all Kratix resources
kubectl get promises,destinations,works,workplacements -A

# Check specific Promise processing
kubectl get works -n kratix-platform-system -l kratix.io/promise=<promise-name>

# View pipeline output
kubectl exec -n kratix-platform-system <pipeline-pod> -- ls -la /kratix/output/
```

### 17.3 Health Check Script

```bash
#!/bin/bash
# kratix-health.sh

echo "=== Kratix Health Check ==="

echo -e "\n## Controllers"
kubectl get pods -n kratix-platform-system

echo -e "\n## Promises"
kubectl get promises

echo -e "\n## Destinations"
kubectl get destinations

echo -e "\n## State Stores"
kubectl get gitstatestores
kubectl get bucketstatestores

echo -e "\n## Works (recent)"
kubectl get works -n kratix-platform-system --sort-by='.metadata.creationTimestamp' | tail -10

echo -e "\n## Recent Events"
kubectl get events -n kratix-platform-system --sort-by='.lastTimestamp' | tail -10
```

---

## 18. Best Practices

### 18.1 Promise Design

1. **Simple APIs** - Hide complexity from developers
2. **Sensible defaults** - Minimize required fields
3. **Validation** - Check inputs early in pipeline
4. **Status updates** - Keep users informed

### 18.2 Pipeline Design

1. **Small images** - Use minimal base images
2. **Idempotent** - Pipelines may re-run
3. **Logging** - Output helpful debug info
4. **Error handling** - Fail fast with clear messages

### 18.3 State Store

1. **Use Git** - Better audit trail
2. **Separate repos** - Per environment/team
3. **Branch protection** - For production paths

### 18.4 Security

1. **RBAC** - Limit Promise creation to platform team
2. **Namespace isolation** - Use dedicated namespaces
3. **Secret management** - Use External Secrets

---

## 19. Reference

### 19.1 Useful Commands

```bash
# Kratix
kubectl get promises
kubectl get destinations
kubectl get works -n kratix-platform-system
kubectl get workplacements -n kratix-platform-system

# Debug
kubectl describe promise <name>
kubectl logs -n kratix-platform-system -l control-plane=controller-manager

# Testing
kratix test promise --promise-file=promise.yaml --input=request.yaml
```

### 19.2 Documentation Links

| Resource | URL |
|----------|-----|
| Kratix Docs | https://kratix.io/docs |
| Kratix GitHub | https://github.com/syntasso/kratix |
| Promise Marketplace | https://kratix.io/marketplace |
| Syntasso | https://syntasso.io |

### 19.3 Promise Examples

| Promise | Description |
|---------|-------------|
| Jenkins | CI/CD server |
| PostgreSQL | Database instance |
| Redis | In-memory cache |
| Namespace | Team workspace |
| App Environment | Complete app stack |

---

**End of Kratix Documentation**
