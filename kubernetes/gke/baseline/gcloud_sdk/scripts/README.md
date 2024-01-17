# Instructions

# Provision GKE

```bash
source env.sh # required variables
./create_projects.sh # done once
./create_gsa.sh      # create google service account for GKE
./create_network.sh  # create network infra for GKE
./create_gke.sh      # create GKE
```

# Remove GKE

```bash
source env.sh # required variables

./delete_gke.sh
./delete_network.sh
./delete_gsa.sh
```
