############
# STEP 1: source env vars
############################################
source env.sh

############
# STEP 2: create namespace
############################################
kubectl get namespace "dgraph" > /dev/null 2> /dev/null || \
 kubectl create namespace "dgraph" && \
 kubectl label namespaces "dgraph" name="dgraph"

############
# STEP 3: deploy dgraph with linkerd proxy containers
############################################
helmfile --file ./examples/dgraph/helmfile.yaml apply
