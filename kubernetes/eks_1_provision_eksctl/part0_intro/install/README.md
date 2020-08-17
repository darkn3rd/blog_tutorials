# Install Scripts

## Prerequisites

The following prerequisites are needed for any platform.

* [Google Cloud SDK](https://cloud.google.com/sdk/install) - required for creating GKE cluster
* [AWS CLI](https://aws.amazon.com/cli/) - required for creating EKS cluster.

## Installing eksctl and kubectl

### Mac

1. Install Homebrew - https://brew.sh/
2. `brew bundle install`

### Windows

1. Install Chocolatey - https://chocolatey.org/install
2. In PowerShell (Administration mode) `choco install choco.xml`

### Linux: Debian or Ubuntu

1. Install `eksctl`: `./install_eksctl_linux.sh`
2. Install `kubectl`: `./install_kubectl_debian.sh`

### Linux: RHEL or CentOS

1. Install `eksctl`: `./install_eksctl_linux.sh`
2. Install `kubectl`: `./install_kubectl_rhel.sh`
