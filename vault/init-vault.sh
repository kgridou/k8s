#!/bin/bash
set -e

echo "Waiting for Vault to be ready..."
sleep 10

# Check if Vault is already initialized
vault_status=$(vault status -format=json 2>/dev/null || echo '{"initialized": false}')
initialized=$(echo "$vault_status" | grep -o '"initialized":[^,}]*' | cut -d':' -f2 | tr -d ' ')

if [ "$initialized" = "true" ]; then
    echo "Vault is already initialized"
    
    # Check if unseal keys exist
    if [ -f "/vault/keys/unseal_keys.txt" ]; then
        echo "Unsealing Vault with existing keys..."
        # Read and use existing unseal keys
        while IFS= read -r key; do
            if [ ! -z "$key" ] && [ "$key" != "root_token:"* ]; then
                vault operator unseal "$key" || true
            fi
        done < /vault/keys/unseal_keys.txt
    else
        echo "WARNING: Vault is initialized but unseal keys not found!"
        echo "You will need to unseal Vault manually."
    fi
    
    exit 0
fi

echo "Initializing Vault..."

# Initialize Vault
init_response=$(vault operator init -key-shares=5 -key-threshold=3 -format=json)

# Extract unseal keys and root token
echo "$init_response" | jq -r '.unseal_keys_b64[]' > /vault/keys/unseal_keys.txt
echo "$init_response" | jq -r '.root_token' > /vault/keys/root_token.txt

echo "Vault initialized successfully!"
echo "Unseal keys and root token saved to /vault/keys/"

# Unseal Vault
echo "Unsealing Vault..."
unseal_keys=($(echo "$init_response" | jq -r '.unseal_keys_b64[]'))
for i in {0..2}; do  # Use first 3 keys to unseal
    vault operator unseal "${unseal_keys[$i]}"
done

echo "Vault unsealed successfully!"

# Login with root token
root_token=$(echo "$init_response" | jq -r '.root_token')
export VAULT_TOKEN="$root_token"

echo "Configuring Vault..."

# Enable audit logging
vault audit enable file file_path=/vault/logs/audit.log

# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Enable Kubernetes auth method
vault auth enable kubernetes

echo "Configuring Kubernetes authentication..."

# Note: For production, you would configure this with actual Kubernetes cluster info
# This is a placeholder configuration - you'll need to run vault-setup-external.sh
# with proper Kubernetes cluster details after the cluster is set up

# Create a policy for the demo-app
vault policy write demo-app-policy - <<EOF
path "secret/data/demo-app/*" {
  capabilities = ["read"]
}

path "secret/data/demo-app" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Add sample secrets
vault kv put secret/demo-app \
    message="Hello from Production Vault!" \
    db.password="production-secret-password" \
    db.username="demo_user" \
    api.key="prod-api-key-12345"

echo "==================================="
echo "Vault setup completed successfully!"
echo "==================================="
echo "Root token: $root_token"
echo "Unseal keys and root token are saved in the vault-keys volume"
echo ""
echo "IMPORTANT: Save these credentials securely!"
echo "Root token is in: /vault/keys/root_token.txt"
echo "Unseal keys are in: /vault/keys/unseal_keys.txt"
echo "==================================="