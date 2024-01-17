# Utility Scripts

These are small little scripts that are useful in learning about the environment.

Example Usage

```bash
linkerd viz install > ../logs/viz_manifests.yaml
linkerd install > ../logs/linkerd_manifests.yaml

./flatten_manifest.sh ../logs/viz_manifests.yaml ../logs/viz_obj.yaml
./flatten_manifest.sh ../logs/linkerd_manifests.yaml ../logs/linkerd_obj.yaml

./print_obj_list.rb ../logs/viz_obj.yaml
./print_obj_list.rb ../logs/linkerd_obj.yaml
```
