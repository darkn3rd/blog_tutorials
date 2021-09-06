JSONPATH_NODES='{range .items[*]}{@.metadata.name}{"\t"}{@.status.addresses[?(@.type == "InternalIP")].address}{"\n"}{end}'
JSONPATH_PODS='{range .items[*]}{@.metadata.name}{"\t"}{@.status.podIP}{"\n"}{end}'

cat <<-EOF
Nodes:
------------
$(kubectl get nodes --output jsonpath="$JSONPATH_NODES" | xargs printf "%-40s %s\n")

Pods:
------------
$(kubectl get pods --output jsonpath="$JSONPATH_PODS" --all-namespaces | \
    xargs printf "%-40s %s\n"
)
EOF
