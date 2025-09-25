ui = true

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_disable     = 0
  tls_cert_file   = "/vault/certs/vault.crt"
  tls_key_file    = "/vault/certs/vault.key"
}

storage "file" {
  path = "/tmp/vault"
}

api_addr = "https://0.0.0.0:8200"
cluster_addr = "https://0.0.0.0:8201"

# Enable logging
log_level = "Info"

# Disable mlock for containers (not recommended for production but needed for Docker)
disable_mlock = true