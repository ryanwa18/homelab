#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Adding Helm repositories ==="
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jenkins https://charts.jenkins.io
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Wave 0: cert-manager
echo "=== Deploying cert-manager ==="
helm dependency build "$SCRIPT_DIR/apps/cert-manager"
helm upgrade --install cert-manager "$SCRIPT_DIR/apps/cert-manager" \
  -n cert-manager --create-namespace --wait

# Wave 1: monitoring
echo "=== Deploying kube-prometheus-stack ==="
helm dependency build "$SCRIPT_DIR/apps/monitoring/kube-prometheus-stack"
helm upgrade --install kube-prometheus-stack "$SCRIPT_DIR/apps/monitoring/kube-prometheus-stack" \
  -n monitoring --create-namespace --wait --timeout 10m

# Wave 2: jenkins + pihole
echo "=== Deploying Jenkins ==="
helm dependency build "$SCRIPT_DIR/apps/jenkins"
helm upgrade --install jenkins "$SCRIPT_DIR/apps/jenkins" \
  -n jenkins --create-namespace --wait --timeout 10m

echo "=== Deploying Pi-hole ==="
helm dependency build "$SCRIPT_DIR/apps/pihole"
helm upgrade --install pihole "$SCRIPT_DIR/apps/pihole" \
  -n pihole --create-namespace --wait

# Wave 3: observability
echo "=== Deploying Tempo ==="
helm dependency build "$SCRIPT_DIR/apps/observability/tempo"
helm upgrade --install tempo "$SCRIPT_DIR/apps/observability/tempo" \
  -n observability --create-namespace --wait

echo "=== Deploying Alloy ==="
helm dependency build "$SCRIPT_DIR/apps/observability/alloy"
helm upgrade --install alloy "$SCRIPT_DIR/apps/observability/alloy" \
  -n observability --create-namespace --wait

echo "=== Deploying OpenTelemetry Operator ==="
helm dependency build "$SCRIPT_DIR/apps/observability/opentelemetry-operator"
helm upgrade --install opentelemetry-operator "$SCRIPT_DIR/apps/observability/opentelemetry-operator" \
  -n observability --create-namespace --wait

echo "=== Deployment complete ==="
helm list -A
