# ArgoCD Bootstrap

This directory contains the manifests needed to bootstrap ArgoCD in your Kubernetes cluster.

## Prerequisites

- Kubernetes cluster (k3s, kind, minikube, or full cluster)
- kubectl configured with cluster access
- Cluster admin privileges

## Installation Steps

### 1. Install ArgoCD

Apply the namespace and ArgoCD installation manifests:

```bash
kubectl apply -f argocd/namespace.yaml
kubectl apply -f argocd/install.yaml
```

### 2. Wait for ArgoCD to be ready

```bash
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
```

### 3. Access ArgoCD UI

Forward the ArgoCD server port to your local machine:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then access the UI at: https://localhost:8080

### 4. Get initial admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Login with:
- Username: `admin`
- Password: (from command above)

### 5. Change admin password (recommended)

```bash
argocd login localhost:8080
argocd account update-password
```

Or change it in the UI under User Info.

### 6. Deploy the app-of-apps

Once ArgoCD is running, deploy the root application that will manage all other applications:

```bash
kubectl apply -f ../argocd-apps/root-app.yaml
```

This will automatically deploy all services (Prometheus, Grafana, Jenkins, Pi-hole, OpenTelemetry) via GitOps.

## Verification

Check that ArgoCD components are running:

```bash
kubectl get pods -n argocd
```

Check that applications are synced:

```bash
kubectl get applications -n argocd
```

## Troubleshooting

### Pods not starting

Check pod status and logs:

```bash
kubectl get pods -n argocd
kubectl logs -n argocd deployment/argocd-server
```

### Can't access UI

Verify the service is running:

```bash
kubectl get svc -n argocd argocd-server
```

Make sure port-forward is active and not conflicting with other processes on port 8080.

### Applications not syncing

Check application status:

```bash
kubectl describe application <app-name> -n argocd
```

View ArgoCD logs:

```bash
kubectl logs -n argocd deployment/argocd-application-controller
```

## Uninstall

To remove ArgoCD:

```bash
kubectl delete -f argocd/install.yaml
kubectl delete -f argocd/namespace.yaml
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD Operator Manual](https://argo-cd.readthedocs.io/en/stable/operator-manual/)
