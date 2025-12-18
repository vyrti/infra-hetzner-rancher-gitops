#!/bin/bash
set -e

mkdir -p dashboards_json

# List of dashboard IDs
DASHBOARDS=(
    "7249:kubernetes-cluster"
    "1860:node-exporter"
    "6336:kubernetes-pods"
    "13639:logs-app"
    "17346:traefik"
    "11001:cert-manager"
    "14584:argocd"
    "15682:gitlab"
    "9628:postgresql"
    "763:redis"
    "13502:minio"
    "7639:istio-mesh"
    "7636:istio-service"
    "17462:mimir-overview"
)

echo "Downloading dashboards..."
for entry in "${DASHBOARDS[@]}"; do
    ID=${entry%%:*}
    NAME=${entry#*:}
    echo "Fetching $NAME (ID: $ID)..."
    curl -sL "https://grafana.com/api/dashboards/${ID}/revisions/latest/download" | \
    sed 's/${DS_MIMIR}/Mimir/g' | \
    sed 's/${DS_PROMETHEUS}/Mimir/g' | \
    sed 's/${ds_prometheus}/Mimir/g' | \
    sed 's/${DS_LOKI}/Loki/g' | \
    sed 's/${DS_TEMPO}/Tempo/g' \
    > "dashboards_json/${NAME}.json"
done

echo "Generating ConfigMaps..."
# Remove old monolithic file if it exists
rm -f dashboards-manifest.yaml

for file in dashboards_json/*.json; do
    BASENAME=$(basename "$file" .json)
    OUTPUT_FILE="${BASENAME}.yaml"
    
    echo "Processing $BASENAME -> $OUTPUT_FILE"
    
    # Create valid YAML with labels using perl for cross-platform safety
    kubectl create configmap "grafana-dashboard-${BASENAME}" \
        --from-file="${BASENAME}.json=${file}" \
        --dry-run=client -o yaml > temp_cm.yaml
        
    perl -i -pe 's/metadata:/metadata:\n  labels:\n    grafana_dashboard: "1"/' temp_cm.yaml
    perl -i -pe 's/creationTimestamp: null//' temp_cm.yaml
    
    mv temp_cm.yaml "$OUTPUT_FILE"
done

echo "Cleaning up..."
rm -rf dashboards_json
echo "Done. Created individual dashboard files."
