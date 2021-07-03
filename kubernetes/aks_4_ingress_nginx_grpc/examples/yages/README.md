

```bash
grpcurl yages.$AZ_DNS_DOMAIN:443 yages.Echo.Ping | jq
grpcurl -d '{ "text" : "some fun here" }' yages.$AZ_DNS_DOMAIN:443 yages.Echo.Reverse
grpcurl yages.$AZ_DNS_DOMAIN:443 list
```
