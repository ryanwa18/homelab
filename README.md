# Homelab Kubernetes GitOps with ArgoCD

A production-grade GitOps infrastructure for your homelab, managed by ArgoCD. This repository contains Kubernetes manifests for deploying and managing a complete monitoring and automation stack.

## Services Deployed

| Service | Description | Access URL |
|---------|-------------|------------|
| **cert-manager** | Automated TLS certificate management | Internal service |
| **Prometheus** | Metrics collection and storage | Port-forward: 9090 |
| **Grafana** | Metrics visualization and dashboards | https://grafana.homelab.local |
| **Jenkins** | CI/CD automation server | https://jenkins.homelab.local |
| **Pi-hole** | DNS ad-blocking and filtering | https://pihole.homelab.local |
| **OpenTelemetry** | Observability collector and processor | Internal service |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        ArgoCD GitOps                         │
│                    (App-of-Apps Pattern)                     │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  Monitoring  │      │   Jenkins    │      │   Pi-hole    │
│  Namespace   │      │  Namespace   │      │  Namespace   │
├──────────────┤      ├──────────────┤      ├──────────────┤
│ Prometheus   │◄─────┤ Jenkins      │      │ Pi-hole      │
│ Grafana      │      │ + Metrics    │      │ + Metrics    │
│ Alertmanager │      └──────────────┘      └──────────────┘
└──────────────┘              │                     │
        ▲                     │                     │
        │                     └─────────┬───────────┘
        │                               │
        │                       ┌───────▼───────┐
        │                       │ Observability │
        │                       │   Namespace   │
        │                       ├───────────────┤
        └───────────────────────┤ OpenTelemetry │
                                │   Collector   │
                                └───────────────┘
```

### Integration Points

1. **Grafana → Prometheus**: Pre-configured datasource for seamless metrics visualization
2. **Jenkins → Prometheus**: ServiceMonitor scrapes Jenkins /prometheus endpoint
3. **Pi-hole → Prometheus**: ServiceMonitor scrapes Pi-hole API metrics
4. **OpenTelemetry → Prometheus**: Remote write exports OTLP metrics to Prometheus

### Sync Waves

ArgoCD deploys services in order using sync waves:

- **Wave 0**: cert-manager - TLS certificate management (must deploy first)
- **Wave 1**: Monitoring stack (Prometheus + Grafana) - Foundation for metrics
- **Wave 2**: Jenkins, Pi-hole - Application services (certificates issued automatically)
- **Wave 3**: OpenTelemetry - Observability collector (requires Prometheus)

## Prerequisites

Before deploying, ensure you have:

- **Kubernetes Cluster**: k3s, kind, minikube, or full cluster
  - Minimum: 4 CPU cores, 8GB RAM
  - Recommended: 8 CPU cores, 16GB RAM
- **kubectl**: Configured with cluster admin access
- **Git**: For repository operations
- **Default StorageClass**: For persistent volumes
  - k3s: Uses `local-path` by default
  - Other clusters: May need to configure storage

### Required Components

- **nginx-ingress-controller**: For web UI access via ingress (required for TLS)

### Optional Components

- **MetalLB**: For Pi-hole LoadBalancer service (DNS)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/ryanwa18/homelab.git
cd homelab
```

### 2. Configure cert-manager Email

**IMPORTANT**: Update the email address in the cert-manager ClusterIssuers for Let's Encrypt notifications:

```bash
# Edit both staging and production ClusterIssuers
vim apps/cert-manager/templates/clusterissuer-letsencrypt-staging.yaml
vim apps/cert-manager/templates/clusterissuer-letsencrypt-prod.yaml

# Replace "your-email@example.com" with your actual email address
```

This email will receive notifications about certificate expiration and renewal issues.

### 3. Bootstrap ArgoCD

```bash
# Install ArgoCD
kubectl apply -k bootstrap/argocd/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
```

### 4. Access ArgoCD UI

```bash
# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Open https://localhost:8080 and login with:
- Username: `admin`
- Password: (from command above)

### 5. Deploy All Services

```bash
# Deploy the root app-of-apps
kubectl apply -f argocd-apps/root-app.yaml
```

ArgoCD will automatically discover and deploy all applications in the correct order.

### 6. Monitor Deployment

```bash
# Watch applications sync
kubectl get applications -n argocd -w

# Check all pods are running
kubectl get pods --all-namespaces
```

## Accessing Services

### Grafana

```bash
# Port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Access: http://localhost:3000
- Username: `admin`
- Password: `changeme` (change this in [values.yaml](apps/monitoring/kube-prometheus-stack/values.yaml))

### Prometheus

```bash
# Port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Access: http://localhost:9090

### Jenkins

```bash
# Port-forward
kubectl port-forward -n jenkins svc/jenkins 8081:8080
```

Access: http://localhost:8081
- Username: `admin`
- Password: `changeme` (change this in [values.yaml](apps/jenkins/values.yaml))

### Pi-hole

```bash
# Port-forward
kubectl port-forward -n pihole svc/pihole-web 8082:80
```

Access: http://localhost:8082/admin
- Password: `changeme` (change this in [values.yaml](apps/pihole/values.yaml))

### Ingress Access with TLS

All services are configured with TLS certificates via cert-manager. To access via ingress:

1. **Get your ingress controller IP**:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   ```

2. **Add entries to `/etc/hosts` or configure DNS**:
   ```
   <INGRESS_IP> grafana.homelab.local
   <INGRESS_IP> jenkins.homelab.local
   <INGRESS_IP> pihole.homelab.local
   ```
   Replace `<INGRESS_IP>` with your ingress controller's external IP.

3. **Access services via HTTPS**:
   - Grafana: https://grafana.homelab.local
   - Jenkins: https://jenkins.homelab.local
   - Pi-hole: https://pihole.homelab.local

**Note**: cert-manager will automatically request and manage TLS certificates from Let's Encrypt. The first time you access a service, certificate issuance may take 1-2 minutes.

## Configuration

### Storage

All services use persistent storage. Update the `storageClassName` in values files if your cluster doesn't have a `standard` StorageClass:

- [Prometheus values](apps/monitoring/kube-prometheus-stack/values.yaml)
- [Jenkins values](apps/jenkins/values.yaml)
- [Pi-hole values](apps/pihole/values.yaml)

### Passwords

**IMPORTANT**: Change default passwords before deploying to production:

```yaml
# apps/monitoring/kube-prometheus-stack/values.yaml
grafana:
  adminPassword: YOUR_SECURE_PASSWORD

# apps/jenkins/values.yaml
jenkins:
  controller:
    adminPassword: YOUR_SECURE_PASSWORD

# apps/pihole/values.yaml
pihole:
  adminPassword: YOUR_SECURE_PASSWORD
```

### TLS Certificates

All ingress resources are configured to use TLS with cert-manager and Let's Encrypt.

#### ClusterIssuers

Two ClusterIssuers are available:

- **letsencrypt-staging**: For testing (higher rate limits, fake certificates)
- **letsencrypt-prod**: For production (real certificates, lower rate limits)

By default, all services use `letsencrypt-prod`. To use staging for testing:

```yaml
# In any values.yaml file
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
```

#### Certificate Status

Check certificate status:

```bash
# List all certificates
kubectl get certificates --all-namespaces

# Check specific certificate
kubectl describe certificate grafana-tls -n monitoring

# View cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

#### Troubleshooting Certificates

If certificates aren't being issued:

1. Check ClusterIssuer status:
   ```bash
   kubectl get clusterissuer
   kubectl describe clusterissuer letsencrypt-prod
   ```

2. Verify email is configured in ClusterIssuer (not your-email@example.com)

3. Check certificate requests:
   ```bash
   kubectl get certificaterequest --all-namespaces
   ```

4. Ensure your domain is publicly accessible on port 80 for HTTP-01 challenge

5. Check Let's Encrypt rate limits if using production issuer

### DNS Configuration

For Pi-hole to work as your DNS server:

1. Get the LoadBalancer IP:
   ```bash
   kubectl get svc -n pihole pihole-dns
   ```

2. Configure your router or devices to use this IP as the DNS server

### Resource Limits

Adjust resource limits based on your cluster capacity in each service's [values.yaml](apps/) file.

## GitOps Workflow

This repository follows the GitOps pattern:

1. **Make changes**: Edit files in this repository
2. **Commit and push**: Push changes to GitHub
3. **Automatic sync**: ArgoCD detects changes and applies them
4. **Self-healing**: ArgoCD reverts manual cluster changes to match Git

### Making Changes

```bash
# Example: Update Grafana to allocate more storage
vim apps/monitoring/kube-prometheus-stack/values.yaml

# Commit and push
git add apps/monitoring/kube-prometheus-stack/values.yaml
git commit -m "Increase Grafana storage to 20Gi"
git push

# ArgoCD automatically syncs within 3 minutes
# Or manually trigger sync:
kubectl patch application kube-prometheus-stack -n argocd \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}' --type merge
```

## Verification

### Check Application Status

```bash
# List all applications
kubectl get applications -n argocd

# Check specific application
kubectl describe application kube-prometheus-stack -n argocd
```

### Check Resources

```bash
# Verify namespaces
kubectl get namespaces | grep -E "cert-manager|monitoring|jenkins|pihole|observability"

# Check all pods
kubectl get pods -n cert-manager
kubectl get pods -n monitoring
kubectl get pods -n jenkins
kubectl get pods -n pihole
kubectl get pods -n observability

# Verify PVCs
kubectl get pvc --all-namespaces
```

### Check ServiceMonitors

```bash
# List ServiceMonitors
kubectl get servicemonitor -n monitoring

# Verify Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Navigate to http://localhost:9090/targets
```

### Check OpenTelemetry

```bash
# Check collector status
kubectl get pods -n observability

# View collector logs
kubectl logs -n observability -l app.kubernetes.io/name=otel-collector

# Verify metrics in Prometheus
# Query for: otelcol_*
```

### Check TLS Certificates

```bash
# List all certificates
kubectl get certificates --all-namespaces

# Check certificate details
kubectl describe certificate grafana-tls -n monitoring
kubectl describe certificate jenkins-tls -n jenkins
kubectl describe certificate pihole-tls -n pihole

# Verify ClusterIssuers are ready
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# Check cert-manager pods
kubectl get pods -n cert-manager
```

Expected output: All certificates should show `READY: True` status.

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
kubectl describe application <app-name> -n argocd

# View sync errors
kubectl logs -n argocd deployment/argocd-application-controller | grep <app-name>

# Manually sync
kubectl patch application <app-name> -n argocd \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}' --type merge
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Check StorageClass
kubectl get storageclass

# Describe PVC
kubectl describe pvc -n <namespace> <pvc-name>
```

### Ingress Not Working

```bash
# Check ingress resources
kubectl get ingress --all-namespaces

# Verify ingress controller
kubectl get pods -n ingress-nginx

# Check ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### ServiceMonitor Not Scraping

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n monitoring

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets

# Check Prometheus operator logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

### Certificate Issues

**Certificate not being issued:**

```bash
# Check certificate status
kubectl get certificate <cert-name> -n <namespace>

# View certificate details and events
kubectl describe certificate <cert-name> -n <namespace>

# Check certificate requests
kubectl get certificaterequest -n <namespace>

# View cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check ClusterIssuer status
kubectl describe clusterissuer letsencrypt-prod
```

**Common issues:**

1. **Email not configured**: Update email in [ClusterIssuer files](apps/cert-manager/templates/)
2. **Domain not publicly accessible**: HTTP-01 challenge requires port 80 accessible from internet
3. **Rate limit exceeded**: Switch to `letsencrypt-staging` for testing
4. **Ingress class mismatch**: Ensure ingress controller class matches ClusterIssuer solver
5. **DNS not resolving**: Verify domain resolves to your ingress IP

**Reset certificate:**

```bash
# Delete certificate to trigger re-issuance
kubectl delete certificate <cert-name> -n <namespace>

# ArgoCD will recreate it automatically
```

## Backup and Recovery

### Backup Strategy

1. **Git is the source of truth**: All configurations are version-controlled
2. **PVC data**: Back up persistent volumes regularly
3. **Secrets**: Store sensitive data in external secret manager (not in Git)

### Backup PVCs

```bash
# Example: Backup Grafana data
kubectl exec -n monitoring <grafana-pod> -- tar czf - /var/lib/grafana > grafana-backup.tar.gz

# Example: Backup Jenkins home
kubectl exec -n jenkins <jenkins-pod> -- tar czf - /var/jenkins_home > jenkins-backup.tar.gz
```

### Disaster Recovery

```bash
# Recreate entire infrastructure from Git
kubectl apply -f bootstrap/argocd/namespace.yaml
kubectl apply -f bootstrap/argocd/install.yaml
kubectl apply -f argocd-apps/root-app.yaml

# Restore PVC data
kubectl exec -n monitoring <grafana-pod> -- tar xzf - -C / < grafana-backup.tar.gz
```

## Directory Structure

```
homelab/
├── README.md                      # This file
├── bootstrap/                     # ArgoCD installation
│   ├── argocd/
│   │   ├── namespace.yaml
│   │   └── install.yaml
│   └── README.md
├── argocd-apps/                   # ArgoCD Applications
│   ├── root-app.yaml              # App-of-apps parent
│   ├── monitoring/
│   ├── jenkins/
│   ├── pihole/
│   └── observability/
├── infrastructure/                # Cluster infrastructure
│   └── namespaces/
└── apps/                         # Application configurations
    ├── monitoring/
    ├── jenkins/
    ├── pihole/
    └── observability/
```

## Customization

### Adding New Applications

1. Create application directory in `apps/`
2. Add Chart.yaml, values.yaml, and templates
3. Create ArgoCD Application manifest in `argocd-apps/`
4. Commit and push - ArgoCD will auto-discover and deploy

### Modifying Sync Waves

Edit the `argocd.argoproj.io/sync-wave` annotation in Application manifests:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Lower numbers deploy first
```

### Disabling Auto-Sync

Remove the `automated` section from Application specs:

```yaml
syncPolicy:
  # Remove this section for manual sync
  # automated:
  #   prune: true
  #   selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

## Maintenance

### Updating Helm Charts

```bash
# Update chart versions in Chart.yaml
vim apps/monitoring/kube-prometheus-stack/Chart.yaml

# Commit and push
git add apps/monitoring/kube-prometheus-stack/Chart.yaml
git commit -m "Update kube-prometheus-stack to v82.0.0"
git push
```

### Scaling Services

```bash
# Update resource requests/limits in values.yaml
vim apps/jenkins/values.yaml

# Commit and push
git add apps/jenkins/values.yaml
git commit -m "Increase Jenkins memory to 6Gi"
git push
```

### Monitoring ArgoCD

```bash
# Check ArgoCD health
kubectl get pods -n argocd

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller
kubectl logs -n argocd deployment/argocd-repo-server
```

## Security Considerations

1. **Change default passwords** before production deployment
2. **Enable TLS** for ingress resources (configure cert-manager)
3. **Use secrets management** for sensitive data (sealed-secrets, external-secrets)
4. **Implement RBAC** for ArgoCD projects and applications
5. **Regular updates** to Helm charts and container images
6. **Network policies** to restrict pod-to-pod communication

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Jenkins Helm Chart](https://github.com/jenkinsci/helm-charts)
- [Pi-hole Kubernetes](https://github.com/MoJo2600/pihole-kubernetes)
- [OpenTelemetry Operator](https://opentelemetry.io/docs/platforms/kubernetes/operator/)
- [GitOps Best Practices](https://www.gitops.tech/)

## Contributing

This is a personal homelab setup. Feel free to fork and adapt for your own use.

## License

This project is provided as-is for educational and personal use.
