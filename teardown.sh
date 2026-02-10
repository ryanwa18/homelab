#!/bin/bash
set -e

echo "=== Tearing down all Helm releases ==="

# Reverse order: wave 3 → wave 0
echo "=== Removing OpenTelemetry Operator ==="
helm uninstall opentelemetry-operator -n observability --ignore-not-found

echo "=== Removing Alloy ==="
helm uninstall alloy -n observability --ignore-not-found

echo "=== Removing Tempo ==="
helm uninstall tempo -n observability --ignore-not-found

echo "=== Removing Pi-hole ==="
helm uninstall pihole -n pihole --ignore-not-found

echo "=== Removing Jenkins ==="
helm uninstall jenkins -n jenkins --ignore-not-found

echo "=== Removing kube-prometheus-stack ==="
helm uninstall kube-prometheus-stack -n monitoring --ignore-not-found

echo "=== Removing cert-manager ==="
helm uninstall cert-manager -n cert-manager --ignore-not-found

echo "=== Cleaning up namespaces ==="
kubectl delete ns observability pihole jenkins monitoring cert-manager --ignore-not-found

echo "=== Teardown complete ==="
