# kv2 secret/dgraph/*
path "secret/data/dgraph/*" {
   capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "secret/metadata/dgraph/*" {
   capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Mount the AppRole auth method
path "sys/auth/approle" {
  capabilities = [ "create", "read", "update", "delete", "sudo" ]
}

# Configure the AppRole auth method
path "sys/auth/approle/*" {
  capabilities = [ "create", "read", "update", "delete" ]
}

# Create and manage roles
path "auth/approle/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Write ACL policies
path "sys/policies/acl/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
