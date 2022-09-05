

# Tests

```bash
# gRPC
curl -sOL https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto
grpcurl -proto api.proto grpc.$DNS_DOMAIN:443 api.Dgraph/CheckVersion
# HTTP
curl --silent https://dgraph.$DNS_DOMAIN/health | jq
curl https://dgraph.$DNS_DOMAIN/state | jq
```

# Client

See [clients](clients/README.md) to load data using gRPC.

Also try out `https://ratel.$DNS_DOMAIN`, subsituting `$DNS_DOMAIN` for the domain used.

## Troubleshooting Certificate

Try curl with more information about certificate negoiation.

```bash
curl -svvI https://dgraph.$DNS_DOMAIN/health
```

Download certificate and look at its parts.

```bash
echo \
  | openssl s_client -showcerts -servername dgraph.$DNS_NAME -connect dgraph.$DNS_NAME:443 2>/dev/null \
  | openssl x509 -inform pem -noout -text
```
