# Generate Root Certificates

You can generate root certificates with the following [`step certificate`](https://smallstep.com/docs/step-cli/reference/certificate/) commands:

```bash
step certificate create root.linkerd.cluster.local ca.crt ca.key \
  --profile root-ca --no-password --insecure

step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
  --profile intermediate-ca --not-after 8760h --no-password --insecure \
  --ca ca.crt --ca-key ca.key
```

## Alternatives

These are some alternative commands that can do the same thing. 

* [mkcert](https://github.com/FiloSottile/mkcert)
* [openssl](https://www.openssl.org/)