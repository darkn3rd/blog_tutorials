# Emissary-Ingress (previously known as Ambassador)

Originally, there was a popular ingress called **Ambassador**, but this has been been renamed to **emissary-ingress**.  **Ambassador** (not to be confused with **Ambassador**) has a enterprise version of this called **Ambassador Edge Stack**.  The enterprise product requires contacting the sales department to get a license, while the OSS is available without any hassle.  Given this, the OSS **emissary-ingress** will be covered in this area. 

Emissary-Ingress is built around the [Envoy Proxy](https://www.envoyproxy.io/) as its core proxy.  [Envoy Proxy](https://www.envoyproxy.io/) was built and open sourced in 2016 by Lyft. 

## Installation

```bash
# Add the Repo:
helm repo add datawire https://app.getambassador.io && helm repo update
 
# Create Namespace and Install:
kubectl create namespace emissary && \
  kubectl apply --filename https://app.getambassador.io/yaml/emissary/3.9.0/emissary-crds.yaml
 
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext --namespace emissary-system
 
helm install emissary-ingress --namespace emissary datawire/emissary-ingress

kubectl --namespace emissary wait --for condition=available --timeout=90s deploy --selector app.kubernetes.io/instance=emissary-ingress
```

## Clean

```bash
helm delete emissary-ingress --namespace emissary
kubectl delete --filename https://app.getambassador.io/yaml/emissary/3.9.0/emissary-crds.yaml
kubectl delete ns emissary
```

## Articles 

* [Envoy Proxy 101: What it is, and why it matters?]https://www.getambassador.io/learn/envoy-proxy)
* [Envoy Gateway Offers to Standardize Kubernetes Ingress](https://thenewstack.io/envoy-gateway-offers-to-standardize-kubernetes-ingress/) by Joab Jackson (The New Stack) on May 16, 2022
* [Lyft’s Envoy: From Monolith to Service Mesh – Matt Klein](https://www.microservices.com/talks/lyfts-envoy-monolith-service-mesh-matt-klein/) video by Matt Klein (Lyft)
* [Introducing Envoy Gateway: An Envoy Proxy-based Gateway for Kubernetes](https://blog.getambassador.io/introducing-envoy-gateway-5b3df54e5f9b) by Richard Li on May 16, 2022
* [From Monolith to Service Mesh, via a Front Proxy — Learnings from stories of building the Envoy Proxy](https://itnext.io/from-monolith-to-service-mesh-via-a-front-proxy-learnings-from-stories-of-building-the-envoy-9dab4b721089)