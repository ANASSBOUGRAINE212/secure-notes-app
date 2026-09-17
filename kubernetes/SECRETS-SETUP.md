# Kubernetes Secrets Setup Guide

## ⚠️ Security Notice

**NEVER commit `secrets.yaml` to git.** It's already in `.gitignore` to prevent accidental commits.

## Quick Setup (Development/Testing)

```bash
# 1. Copy the example template
cp kubernetes/secrets.yaml.example kubernetes/secrets.yaml

# 2. Generate a secure JWT secret
openssl rand -hex 32

# 3. Edit the file and replace all CHANGE_ME placeholders
nano kubernetes/secrets.yaml  # or vim, code, etc.

# 4. Apply to your cluster
kubectl apply -f kubernetes/secrets.yaml
```

## Production Secrets Management

### Option 1: Sealed Secrets (Recommended for GitOps)

Sealed Secrets encrypts your secrets so they CAN be safely committed to git, but only your cluster can decrypt them.

```bash
# Install the controller (one-time)
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
# macOS:
brew install kubeseal

# Linux:
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xfz kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Create your secrets.yaml with real values, then encrypt it:
kubeseal -f kubernetes/secrets.yaml -w kubernetes/sealed-secrets.yaml

# Now you can safely commit sealed-secrets.yaml
git add kubernetes/sealed-secrets.yaml
git commit -m "Add encrypted secrets"

# The controller will automatically decrypt and create the Secret
kubectl apply -f kubernetes/sealed-secrets.yaml
```

### Option 2: External Secrets Operator

Use this if you're already storing secrets in a cloud provider or Vault.

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Create a SecretStore pointing to your provider (example: AWS)
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: secure-notes
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
EOF

# Create an ExternalSecret to sync from AWS
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: notes-secrets
  namespace: secure-notes
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: notes-secrets
  data:
  - secretKey: JWT_SECRET
    remoteRef:
      key: secure-notes/jwt-secret
  - secretKey: AUTH_DB_PASSWORD
    remoteRef:
      key: secure-notes/auth-db-password
  # ... etc
EOF
```

### Option 3: GitLab CI/CD Variables

Store secrets in GitLab and have your pipeline create them during deployment.

```bash
# In GitLab: Settings > CI/CD > Variables, add:
# - AUTH_DB_PASSWORD (protected, masked)
# - NOTES_DB_PASSWORD (protected, masked)
# - JWT_SECRET (protected, masked)

# Then add to your .gitlab-ci.yml:
deploy-secrets:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl create secret generic notes-secrets 
        --namespace=secure-notes 
        --from-literal=AUTH_DB_PASSWORD="$AUTH_DB_PASSWORD"
        --from-literal=NOTES_DB_PASSWORD="$NOTES_DB_PASSWORD"
        --from-literal=JWT_SECRET="$JWT_SECRET"
        --from-literal=AUTH_DB_USER="auth_user"
        --from-literal=NOTES_DB_USER="notes_user"
        --from-literal=AUTH_DB_NAME="auth_db"
        --from-literal=NOTES_DB_NAME="notes_db"
        --from-literal=AUTH_DATABASE_URL="postgresql://auth_user:$AUTH_DB_PASSWORD@auth-db:5432/auth_db"
        --from-literal=NOTES_DATABASE_URL="postgresql://notes_user:$NOTES_DB_PASSWORD@notes-db:5432/notes_db"
        --dry-run=client -o yaml | kubectl apply -f -
  only:
    - main
```

### Option 4: Manual kubectl create

Simple but requires manual intervention on each cluster.

```bash
# Generate a strong JWT secret first
JWT_SECRET=$(openssl rand -hex 32)

# Create the secret
kubectl create secret generic notes-secrets \
  --namespace=secure-notes \
  --from-literal=AUTH_DB_USER="auth_user" \
  --from-literal=AUTH_DB_PASSWORD="your-strong-password-here" \
  --from-literal=AUTH_DB_NAME="auth_db" \
  --from-literal=NOTES_DB_USER="notes_user" \
  --from-literal=NOTES_DB_PASSWORD="your-strong-password-here" \
  --from-literal=NOTES_DB_NAME="notes_db" \
  --from-literal=AUTH_DATABASE_URL="postgresql://auth_user:your-password@auth-db:5432/auth_db" \
  --from-literal=NOTES_DATABASE_URL="postgresql://notes_user:your-password@notes-db:5432/notes_db" \
  --from-literal=JWT_SECRET="$JWT_SECRET"

# Verify it was created
kubectl get secret notes-secrets -n secure-notes
kubectl describe secret notes-secrets -n secure-notes
```

## Rotating Secrets

```bash
# To update a secret:
kubectl delete secret notes-secrets -n secure-notes
# Then recreate it with new values using one of the methods above

# Or patch individual keys:
kubectl patch secret notes-secrets -n secure-notes \
  --type='json' \
  -p='[{"op":"replace","path":"/data/JWT_SECRET","value":"'$(echo -n "new-secret" | base64)'"}]'

# After rotating JWT_SECRET, restart all services:
kubectl rollout restart deployment/auth-service -n secure-notes
kubectl rollout restart deployment/notes-service -n secure-notes
```

## Verification

```bash
# Check if secret exists
kubectl get secret notes-secrets -n secure-notes

# View secret keys (not values)
kubectl describe secret notes-secrets -n secure-notes

# Decode and view actual values (careful in production!)
kubectl get secret notes-secrets -n secure-notes -o jsonpath='{.data.JWT_SECRET}' | base64 -d

# Check which pods are using the secret
kubectl get pods -n secure-notes -o json | jq '.items[] | select(.spec.containers[].env[]?.valueFrom.secretKeyRef.name=="notes-secrets") | .metadata.name'
```

## Troubleshooting

**Pod stuck in CrashLoopBackOff or ImagePullBackOff:**
```bash
# Check if secret exists first
kubectl get secret notes-secrets -n secure-notes

# If missing, create it
# Then check pod logs
kubectl logs -n secure-notes deployment/auth-service
```

**"Secret not found" errors:**
```bash
# Ensure secret is in the correct namespace
kubectl get secrets -A | grep notes-secrets

# If in wrong namespace, recreate in correct one:
kubectl get secret notes-secrets -n wrong-namespace -o yaml | \
  sed 's/namespace: wrong-namespace/namespace: secure-notes/' | \
  kubectl apply -f -
```

**Need to inspect secret format:**
```bash
# Export to YAML for inspection
kubectl get secret notes-secrets -n secure-notes -o yaml

# Compare with your secrets.yaml.example
diff <(kubectl get secret notes-secrets -n secure-notes -o yaml) kubernetes/secrets.yaml.example
```
