# GKE 5: Deploying Ingress with Managed SSL

Note that creating a LoadBalancer and updating a new DNS record can take a while to become functional (3-5 minutes).  Addtionally, even after a certificate enters an active state, it can still be come time before it will function correctly.

You may initially encounter such errors:
  * Firefox: `SSL_ERROR_NO_CYPHER_OVERLAP`
  * Chrome: `ERR_SSL_VERSION_OR_CIPHER_MISMATCH`

## Part 1 

Deploy ingress with managed SSL certificate for ephemeral IP address.

* Part 2 [README.md](part1_ephemeral_ip/README.md)

## Part 2

Deploy ingress with managed SSL certificate for reserved IP address.

* Part 2 [README.md](part2_reserved_ip/README.md)

