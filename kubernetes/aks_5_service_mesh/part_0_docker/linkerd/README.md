# Linkerd Images

Linkerd uses [GitHub Packages](https://github.com/features/packages), which has shown problems containerd on Kubernetes.  To get around this issue, we can push the images to an alernative source.

## Fetch List of Images

```bash
linkerd install --ignore-cluster | grep -oP '(?<=image: ).*$' | sort | uniq > linkerd_images.txt
linkerd viz install | grep -oP '(?<=image: ).*$' | grep -F 'cr.l5d.io' | sort | uniq >> linkerd_images.txt
linkerd jaeger install | grep -oP '(?<=image: ).*$' | grep -F 'cr.l5d.io' | sort | uniq >> linkerd_images.txt
```

## Republish images

```bash
cat linkerd_images.txt | xargs -n 1 docker pull
for IMAGE in $(cat containers.txt); do
  docker tag $IMAGE ${AZ_ACR_LOGIN_SERVER}/${IMAGE#*/}
  docker push ${AZ_ACR_LOGIN_SERVER}/${IMAGE#*/}
done
```
