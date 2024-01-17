# Install Linkerd through Linkerd CLI 

This is the easiest method to get started.  For production, I would explore using Helm chart, and setting up a scalable Prometheus. 

## Install Linkerd CLI


### macOS with Homebrew

```bash
brew install linkerd
```

### universal installer


```bash
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$HOME/.linkerd2/bin:$PATH
```

## Installation

```bash
# precheck 
linkerd check --pre

# install 
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -


# verify install
linkerd check
```

## Linkerd Viz

```bash
linkerd viz install | kubectl apply -f -
```

## Demo Application

```bash
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml \
  | kubectl apply -f -
kubectl -n emojivoto port-forward svc/web-svc 8080:80
kubectl get -n emojivoto deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -
linkerd -n emojivoto check --proxy
```