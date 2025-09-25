# Production Vault Setup with Docker Compose

This setup runs HashiCorp Vault in **production mode** using Docker Compose with file storage backend.

## 🚀 Quick Start

### 1. Start Vault in Production Mode

```bash
# Start Vault and initialization
docker compose up -d

# Check logs to see initialization
docker compose logs vault-init

# View the root token and unseal keys
docker compose exec vault cat /vault/keys/root_token.txt
```

### 2. Configure Kubernetes Authentication

The application is configured to use Kubernetes authentication. To set this up:

```bash
# Get the root token for Vault administration
export VAULT_TOKEN=$(docker compose exec vault cat /vault/keys/root_token.txt)

# Deploy the application with ServiceAccount to Kubernetes
kubectl apply -f k8s/

# Configure Vault for Kubernetes auth (run this script with your K8s cluster)
./vault-setup-external.sh
```

For local testing with token auth, you can override the authentication method:

```bash
# Set environment variable to use token auth locally
export VAULT_TOKEN=$(docker compose exec vault cat /vault/keys/root_token.txt)
# Set SPRING_CLOUD_VAULT_AUTHENTICATION=TOKEN when running locally
```

### 3. Test Vault Access

```bash
# Test Vault API
curl http://localhost:8200/v1/sys/health

# List secrets (requires token)
curl -H "X-Vault-Token: $VAULT_TOKEN" \
     http://localhost:8200/v1/secret/data/demo-app
```

## 🏗️ Architecture

### Production Vault Features
- **File Storage Backend**: Persistent storage in Docker volume
- **Proper Initialization**: 5 key shares, 3 key threshold
- **Audit Logging**: Enabled and logged to `/vault/logs/audit.log`
- **Auto-Unsealing**: Automatic unseal on startup using saved keys
- **Secrets Management**: KV v2 secrets engine enabled

### Services
- **vault**: Main Vault server in production mode
- **vault-init**: One-time initialization container

### Volumes
- **vault-data**: Vault's persistent data storage
- **vault-logs**: Vault audit and application logs
- **vault-keys**: Unseal keys and root token storage

## 🔧 Configuration Files

### `vault/config.hcl`
```hcl
ui = true
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
storage "file" {
  path = "/vault/data"
}
api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"
log_level = "Info"
disable_mlock = true
```

### `vault/init-vault.sh`
- Checks if Vault is already initialized
- Initializes Vault with 5 key shares, 3 key threshold
- Saves unseal keys and root token to persistent volume
- Unseals Vault automatically
- Enables audit logging and KV v2 secrets engine
- Adds sample secrets for demo-app

## 🔐 Security Features

### Initialization Process
1. **Key Shares**: 5 unseal keys generated
2. **Threshold**: Requires 3 keys to unseal
3. **Root Token**: Securely generated and stored
4. **Audit Logging**: All API calls logged

### Persistent Storage
- **Unseal Keys**: Stored in `vault-keys` volume
- **Root Token**: Stored in `vault-keys` volume
- **Data**: Stored in `vault-data` volume
- **Logs**: Stored in `vault-logs` volume

## 📋 Available Secrets

The initialization script creates sample secrets at `secret/demo-app`:

```json
{
  "message": "Hello from Production Vault!",
  "db.password": "production-secret-password",
  "db.username": "demo_user",
  "api.key": "prod-api-key-12345"
}
```

## 🔧 Managing Vault

### Common Operations

```bash
# Check Vault status
docker compose exec vault vault status

# List secrets
docker compose exec vault vault kv list secret

# Add new secret
docker compose exec vault vault kv put secret/demo-app new.secret="new-value"

# Read specific secret
docker compose exec vault vault kv get secret/demo-app

# View audit logs
docker compose exec vault tail -f /vault/logs/audit.log
```

### Backup and Restore

```bash
# Backup Vault data
docker run --rm -v k8s_vault-data:/data -v $(pwd):/backup alpine \
    tar czf /backup/vault-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore Vault data (when Vault is stopped)
docker compose down
docker run --rm -v k8s_vault-data:/data -v $(pwd):/backup alpine \
    tar xzf /backup/vault-backup-YYYYMMDD.tar.gz -C /data
docker compose up -d
```

## 🚨 Important Security Notes

### For Production Use:
1. **Enable TLS**: Set `tls_disable = 0` and configure certificates
2. **Secure Root Token**: Store root token in secure credential management system
3. **Rotate Keys**: Regularly rotate unseal keys and root token
4. **Network Security**: Use proper network segmentation and firewall rules
5. **Backup Strategy**: Implement regular automated backups
6. **Monitor Audit Logs**: Set up log monitoring and alerting

### Current Limitations (Development Setup):
- TLS disabled for simplicity
- Root token stored in plain text
- File storage backend (use Consul/etcd for HA in production)
- No auto-unsealing mechanism (use cloud KMS in production)

## 🔍 Troubleshooting

### Vault Won't Start
```bash
# Check logs
docker compose logs vault

# Check configuration
docker compose exec vault vault status
```

### Vault Sealed
```bash
# Check seal status
docker compose exec vault vault status

# Manually unseal if needed
docker compose exec vault vault operator unseal <unseal-key>
```

### Lost Root Token
```bash
# Generate new root token (requires threshold of unseal keys)
docker compose exec vault vault operator generate-root
```

### Reset Vault (⚠️ Destroys all data)
```bash
docker compose down -v  # Removes all volumes
docker compose up -d    # Reinitializes
```