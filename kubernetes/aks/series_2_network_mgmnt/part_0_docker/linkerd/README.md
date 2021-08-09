# Linkerd Images

Linkerd uses [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), which has shown problems containerd on Kubernetes.  To get around this issue, we can push the images to an alernative source.

## Requirements

### GNU Grep

This script uses [GNU grep](https://www.gnu.org/software/grep/), specifically for the [Perl Regular expressions](https://www.pcre.org/) features.

If you are on macOS and [Homebrew](https://brew.sh/), you can get this with the following command:

```bash
brew install grep
export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
```

## Republish Linkerd Images

```bash
REGISTRY=${AZ_ACR_LOGIN_SERVER}
az acr login --name ${AZ_ACR_NAME}
./republish_linkerd_images.sh
```

## Republish Extension Images

Linkerd has to be installed into the `linkerd` namespace before running this script.

```bash
REGISTRY=${AZ_ACR_LOGIN_SERVER}
az acr login --name ${AZ_ACR_NAME}
./republish_extension_images.sh
```

## Verify Images are published on ACR

When completed, verify the images are published:

```bash
az acr repository list --name ${AZ_ACR_NAME} --output table | grep linkerd
```

## Alternative to ACR

If you wish to publish to another registry, then just set the `AZ_ACR_LOGIN_SERVER` value. For example:

```bash
export AZ_ACR_LOGIN_SERVER="docker.io"
```
