# NGINX Service Mesh (NSM)

This tutorial will deploy NSM service mesh.  There are a few options that you can set before deploying:


* Auto-Injection (`export NSM_AUTO_INJECTION=false` to disable) - this will put everything deployed in the cluster on the service mesh.
* Strict vs Permissive (`export NSM_MTLS_MODE=permissive`) - this will required that mTLS is used to communicate to the service is set use `export NSM_MTLS_MODE=strict`, otherwise, anything can connect with `permissive`.
