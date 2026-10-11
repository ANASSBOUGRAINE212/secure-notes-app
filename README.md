# Secure Notes

Secure Notes is a small notes app built from a browser frontend, an Nginx gateway, two FastAPI services, and separate PostgreSQL databases for authentication and notes. It is also a DevSecOps learning project: every push is tested and security-scanned by GitLab CI, and Argo CD deploys the result to Kubernetes from Git.

## Architecture

![Secure Notes architecture](docs\secure-notes-devsecops-icons-embedded.drawio.png)

- The auth service handles registration, login, and JWTs.
- The notes service stores notes and verifies JWTs.
- The gateway routes `/auth` and `/notes` to the APIs.
- The frontend uses those same paths, so it works behind the Kubernetes Ingress.

The repository also includes Terraform and Ansible:

- **Terraform** runs against MiniStack, an AWS emulator, to validate the infrastructure code. MiniStack cannot create real VMs, so Terraform does not provision the cluster.
- **Ansible** configures Ubuntu VMs with kubeadm and Argo CD. The cluster VMs are created manually in VMware, then configured with Ansible: set their addresses in the Ansible inventory and skip Terraform for the cluster.

## Repository layout

| Path | Contents |
| --- | --- |
| `auth-service/`, `notes-service/` | FastAPI services and tests |
| `frontend/`, `gateway/` | Browser app and Nginx gateway |
| `docker/` | Docker Compose setup for local development |
| `helm/secure-notes/` | Kubernetes Helm chart |
| `argocd/` | Argo CD Application and repository-secret example |
| `kubernetes/` | Secret example and standalone manifests used for local testing |
| `ansible/` | VM setup, hardening, Kubernetes, and Argo CD roles |
| `terraform/` | MiniStack (AWS emulator) infrastructure configuration |
| `.gitlab-ci.yml` | Build, test, scan, and manifest-update jobs |

## CI/CD flow

The GitLab pipeline runs the service tests and the security checks below, builds four images, and pushes them to Docker Hub. On `main`, `update-manifests` updates the image tags in `helm/secure-notes/values.yaml` and pushes the change back to GitLab. Argo CD watches that chart and syncs it to Kubernetes.

| Check | Tool | What it covers |
| --- | --- | --- |
| Unit tests | pytest | Auth and notes services |
| SAST | Semgrep | Insecure patterns in the source code |
| Dependency scanning | OWASP Dependency-Check, GitLab dependency scanning | Known vulnerabilities in Python libraries |
| Secret detection | GitLab secret detection | Credentials committed to the repository |
| Image scanning | Trivy | OS packages and libraries in the built images; HIGH and CRITICAL findings fail the job <!-- confirm --> |

Set `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as masked GitLab CI/CD variables. GitLab also needs to allow repository pushes from `CI_JOB_TOKEN` for the `update-manifests` job.

## Security

- **Container images:** multi-stage builds that run as a non-root user, with an unprivileged Nginx image for the web containers.
- **Resource limits and health checks:** the Helm chart sets CPU and memory limits and health checks, so one misbehaving pod cannot starve the node.
- **Secrets kept out of Git:** `.env`, `kubernetes/secrets.yaml`, and `argocd/repo-secret.yaml` are ignored by Git; only `.example` files are committed. The values reach the cluster as Kubernetes Secrets, never inside images or the chart.
- **Databases internal only:** each service has its own PostgreSQL database, reachable only inside the cluster through ClusterIP services.
- **Authentication:** JWT-based login, passwords hashed with bcrypt, and CORS restricted to the app's own origins.
- **Node hardening:** an Ansible `hardening` role applies a baseline to the Kubernetes nodes.
- **GitOps delivery:** cluster changes come from Git through Argo CD, so every deployment is traceable to a commit.


## Lab environment

The lab runs as three VMware VMs on one Windows laptop.

| VM | Role | vCPU | RAM | Disk |
| --- | --- | --- | --- | --- |
| Ubuntu controller VM | Docker Compose, self-hosted GitLab and runner, Ansible, Terraform and MiniStack, Minikube | 2 <!-- confirm --> | 4 GB <!-- confirm --> | existing disk |
| `k8s-control-plane-1` | kubeadm control plane (API server, etcd, scheduler, controller manager) | 2 <!-- confirm --> | 4 GB | 30 GB <!-- confirm --> |
| `k8s-worker-1` | Application pods, Argo CD, Traefik, PostgreSQL | 2 <!-- confirm --> | 4 GB | about 40 GB <!-- confirm --> |

The worker started with 2 GB of RAM. With that, the Argo CD repo-server repeatedly failed its liveness probe and was restarted, so the worker was raised to 4 GB. Treat 4 GB as the practical size for a worker that runs the app, Argo CD, Traefik, and two PostgreSQL pods. 

PS: Stop Docker Compose and MiniStack while the Kubernetes cluster is running to save memory.

## Deploy to the Kubernetes VMs

The following assumes Ubuntu VMs with a kubeadm cluster already created, both nodes `Ready`, and `kubectl` access from the control-plane VM. PostgreSQL needs a default StorageClass. If the cluster does not have one, install Rancher's local-path provisioner:

```sh
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
kubectl patch storageclass local-path --type merge \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

This stores database data on the node's local disk; it is suitable for this lab, not highly available storage.

### 1. Set the Ingress class

In `helm/secure-notes/values.yaml`, use:

```yaml
# Ingress
ingress:
  enabled: true
  className: traefik
  annotations: {}
```

Committing this setting so Argo CD applies the Ingress with class `traefik`.

### 2. Configure secrets and Argo CD

On the Ansible machine, copy the examples and fill in the real values:

```sh
cp argocd/repo-secret.yaml.example argocd/repo-secret.yaml
cp kubernetes/secrets.yaml.example kubernetes/secrets.yaml
```

In `argocd/repo-secret.yaml`, use the GitLab project URL, a GitLab username, and a token with `read_repository` permission. In `kubernetes/secrets.yaml`, set the database URLs and a strong `JWT_SECRET`. The live files are ignored by Git; never commit them.

Set the VM addresses and SSH settings in `ansible/inventory.ini` and `ansible/group_vars/all.yml`, then bootstrap Argo CD from the repository's `ansible/` directory:

```sh
ansible-playbook -i inventory.ini site.yml --tags argocd \
  --private-key ~/.ssh/secure-notes-key --become --ask-become-pass -T 60
```

The play applies the repository credentials and app secret, then registers `argocd/application.yaml`. The application tracks the `main` branch and deploys the Helm chart.

### 3. Install Traefik

Running these commands on the control-plane VM. Traefik is installed into the cluster as a NodePort service:

```sh
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set service.spec.type=NodePort \
  --set ports.web.nodePort=30080 \
  --set ports.websecure.nodePort=30443 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=false \
  --set ingressClass.name=traefik \
  --set providers.kubernetesIngress.enabled=true \
  --wait --timeout 5m
```

Check the controller and app:

```sh
kubectl get pods -n traefik
kubectl get svc -n traefik
kubectl get ingress -n secure-notes
kubectl get pods -n secure-notes
kubectl get applications -n argocd
```

Open the app at `http://<node-ip>:30080`, using the private IP of either Kubernetes node. This address is available only to machines that can reach the VM network. Access from another Wi-Fi device depends on VMware networking and firewall rules; bridged mode is usually needed for LAN access. This setup does not provide a public IP or HTTPS certificate.

## Local development with Docker Compose

Copy `.env.example` to `.env`, set local secrets, then run from the repository root:

```sh
docker compose --env-file .env -f docker/docker-compose.yml up --build
```

Open the frontend at `http://localhost:5500`. The frontend uses the gateway on port `8081` for this local setup. In Kubernetes it uses the Ingress on the same address as the frontend. Stop the stack with `Ctrl+C`, then run:

```sh
docker compose --env-file .env -f docker/docker-compose.yml down
```

## Notes

- `kubernetes/` contains standalone manifests for local testing (Minikube); Argo CD deploys the Helm chart.
- The chart uses `dockerhub-secret` as an image pull secret. Creating it in the `secure-notes` namespace if your Docker Hub repositories are private.
- Terraform targets MiniStack, an AWS emulator, so it validates the infrastructure code but does not create the cluster VMs. Its example configuration includes public VM networking; review SSH and firewall rules before pointing it at a real cloud.
- This is a learning setup, not a production deployment guide. Add TLS, backups, monitoring, and a managed secret solution before using real data.