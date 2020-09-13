#!/usr/bin/env bash
set -eo pipefail

# configure MinIO Client
/usr/local/bin/mc alias set myazure http://${AZURE_GATEWAY}:9000 ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}

# configure s3cfg
cat <<-EOF > ~/.s3cfg
# Setup endpoint: hostname of the Web App
host_base = ${AZURE_GATEWAY}:9000
host_bucket = ${AZURE_GATEWAY}:9000
# Leave as default
bucket_location = us-east-1
use_https = False

access_key = ${MINIO_ACCESS_KEY}
secret_key = ${MINIO_SECRET_KEY}

# Use S3 v4 signature APIs
signature_v2 = False
EOF

exec "$@"
