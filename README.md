# Secure Notes

Secure Notes is a small web app and a learning project for infrastructure and application delivery. It has a browser interface, an Nginx gateway, two FastAPI services, and a separate PostgreSQL database for each service.

The infrastructure here is built with Terraform against MiniStack, an AWS-style local emulator. Ansible prepares the virtual machines, then installs Kubernetes with kubeadm. The app is packaged with Helm and ArgoCD watches the Git repository and deploys chart changes. This is a self-managed Kubernetes cluster on VMs; it does not use EKS.

```text
Terraform → MiniStack VMs → Ansible → Kubernetes
GitLab → CI pipeline → Docker Hub → Helm chart in Git → ArgoCD → Kubernetes
```

## What the app contains

- **Frontend:** HTML, CSS, and JavaScript for the browser.
- **Nginx gateway:** routes requests to the right API.
- **Auth service:** handles user registration and authentication.
- **Notes service:** handles notes.
- **Auth DB and Notes DB:** separate PostgreSQL databases.

In a cluster, Helm creates the app resources and ArgoCD keeps them in sync with the chart in Git. Docker Compose is also available for local app development without the Terraform and Kubernetes setup.

## Project map

| Path | What you will find |
| --- | --- |
| `terraform/` | MiniStack provider settings, VPC, subnet, security groups, VMs, inputs, and outputs. |
| `ansible/` | Main playbook and roles for base setup, hardening, and Kubernetes. |
| `helm/secure-notes/` | Chart metadata, default settings, and templates for the app and databases. |
| `argocd/` | ArgoCD application and repository credentials example. |
| `kubernetes/` | Standalone Kubernetes manifests kept as a reference; the ArgoCD application uses Helm. |
| `auth-service/`, `notes-service/` | Python APIs and their tests. |
| `gateway/`, `frontend/` | Nginx configuration and browser app. |
| `docker/` | Docker Compose configuration for local development. |
| `.gitlab-ci.yml` | Existing GitLab build, test, scan, and image-tag update jobs. |

## Before starting

For the full infrastructure route, you need MiniStack running, Terraform, Ansible, Helm, kubectl, an SSH key pair, Git, and access to the GitLab repository. Docker Hub credentials are needed if the images are private or if you want the pipeline to push images. Ansible is easiest to run from Linux or WSL.

The example values are starting points. Check that the AMI and instance types are available in your MiniStack setup before applying Terraform. Keep your private SSH key on your machine.

## 1. Create the VMs with Terraform

Terraform creates a VPC, a public subnet, security groups, and EC2-style instances through MiniStack. The default VPC range is `10.0.0.0/16`; the subnet is carved from that private range. The instances also receive public IPs so you can reach them from your machine. A private VPC range and public instance IPs serve different purposes and can be used together.

From the repository root, prepare your local settings and then run Terraform from its directory:

```sh
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. In particular, set `ssh_public_key` to the contents of your public key file and check the MiniStack endpoint, AMI, region, and SSH source range. The example SSH rule allows `0.0.0.0/0` (any IPv4 address); set `allowed_ssh_cidr` to your own public address range where possible. Then:

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Read the plan before creating resources. If it looks right, run `terraform apply` and confirm the prompt. Terraform's outputs include public and private IPs and inventory lines for Ansible. State files and `terraform.tfvars` are local files and must stay out of Git.

## 2. Prepare the VMs with Ansible

Ansible uses an **inventory** to know which machines to connect to. Copy the examples and fill in the control-plane and worker addresses from Terraform's outputs:

```sh
cd ../ansible
cp inventory.ini.example inventory.ini
cp group_vars/all.yml.example group_vars/all.yml
```

Check the SSH private-key path and the settings in `group_vars/all.yml`. The roles in `site.yml` run in this order:

1. `common` installs base packages and prepares Linux for Kubernetes.
2. `hardening` applies the configured SSH, firewall, update, and logging settings.
3. `kubernetes` installs containerd and Kubernetes packages, initializes the control plane, joins workers, and installs the configured pod network plugin.

Here, a **playbook** lists the work, a **role** groups related tasks, and a **task** calls an Ansible module to make one change. For example, a package task uses the package manager module instead of running an ad hoc shell command.

From `ansible/`, check connectivity and run the playbook:

```sh
ansible all -m ping
ansible-playbook --syntax-check site.yml
ansible-playbook site.yml
```

After it finishes, use SSH to the control-plane machine and check `kubectl get nodes`. The nodes should report `Ready`. To use `kubectl` from your own machine, copy `~/.kube/config` from the control-plane VM to your local `~/.kube/config` with `scp`; use the control-plane public IP from Terraform and the same SSH key. Keep this file private because it grants cluster access.

## 3. Set up ArgoCD and the app's secrets

Install ArgoCD in the cluster and wait for its pods to be ready. For a learning cluster, the upstream install manifest can be applied like this:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

To open the web UI from your machine, forward the ArgoCD service in a terminal and visit `https://localhost:8080`:

```sh
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

The initial admin password is stored in the `argocd-initial-admin-secret` Kubernetes Secret. Read it only on your own machine and change it after logging in. The ArgoCD application is in `argocd/application.yaml`; it watches the `helm/secure-notes` chart on the `main` branch. Change its `repoURL` to the Git URL that ArgoCD can reach. The checked-in example URL is specific to one GitLab network and will not work from every machine.

If the repository is private, configure its credentials in ArgoCD. Use `argocd/repo-secret.yaml.example` as a guide, put your own credentials only in the ignored local `argocd/repo-secret.yaml`, and never commit that live file. Rotate any credential that may have been exposed.

The chart expects a Kubernetes Secret called `notes-secrets` by default (`secrets.create: false`). It needs database usernames, passwords and names, the two database URLs, and `JWT_SECRET`. A starting point is `kubernetes/secrets.yaml.example`: copy it to the ignored `kubernetes/secrets.yaml`, replace every `CHANGE_ME` value, and apply it after the `secure-notes` namespace exists:

```sh
kubectl apply -f kubernetes/secrets.yaml
```

The two database URLs must use the same usernames and passwords set in that file. Use random values for both database passwords and for `JWT_SECRET`. The chart also refers to `dockerhub-secret` for image pulls. If needed, create it in the same namespace with your Docker Hub username and access token:

```sh
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_TOKEN \
  --docker-email=YOUR_EMAIL \
  --namespace=secure-notes
```

Do not put actual passwords or tokens in the chart, Git, or this README. The files under `kubernetes/` include example manifests, but ArgoCD deploys the Helm chart.

The chart defaults to one replica per app component and one PostgreSQL pod per database. It requests persistent volumes using the cluster's default storage class. Ingress is enabled in the chart values, but you may need to set an ingress class and hostname for your cluster. For a local check, port-forward the gateway service after deployment.

## 4. Deploy the chart

You can inspect the chart before deploying it:

```sh
cd ..
helm lint ./helm/secure-notes
helm template secure-notes ./helm/secure-notes
```

`helm template` prints the Kubernetes YAML locally; it does not contact a cluster. For the GitOps flow, apply `argocd/application.yaml` after the repository URL and required secrets are configured. ArgoCD then renders the chart with Helm and syncs the resources into the `secure-notes` namespace.

Useful checks once it is running:

```sh
kubectl get nodes
kubectl get pods -n secure-notes
kubectl get services -n secure-notes
kubectl get events -n secure-notes --sort-by=.lastTimestamp
```

To open the app locally, forward the gateway service and visit `http://localhost:8080`:

```sh
kubectl port-forward -n secure-notes svc/gateway 8080:80
```

## How the GitLab pipeline fits in

The existing `.gitlab-ci.yml` builds the four application images, runs the configured tests and security scans, and pushes images to Docker Hub. On `main`, `update-manifests` uses `yq` to change the four image tags in `helm/secure-notes/values.yaml` to the commit's short SHA, then commits and pushes that change to GitLab. ArgoCD notices the chart update and deploys the new image versions.

The pipeline does not install Helm or deploy directly to Kubernetes. Set `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as GitLab CI variables for image publishing. The pipeline's actual jobs and conditions are defined in `.gitlab-ci.yml`.

## Run the app with Docker Compose

For app development without the cluster, copy `.env.example` to `.env`, fill in the local values, and run this from the repository root:

```sh
docker compose --env-file .env -f docker/docker-compose.yml up --build
```

The frontend is available at `http://localhost:8080`; the APIs use ports `8001` and `8002`. Keep `.env` local. To stop the containers, press `Ctrl+C` and run `docker compose --env-file .env -f docker/docker-compose.yml down`.

## What this setup is for

This is a learning/demo setup built around MiniStack, public VM addresses, and a self-managed Kubernetes cluster. It is not a production deployment recipe. Before using a real cloud account, review network exposure, SSH rules, Kubernetes access, secret storage, backups, TLS, monitoring, logging, and recovery. In particular, do not carry the example's open SSH range into a public environment.
