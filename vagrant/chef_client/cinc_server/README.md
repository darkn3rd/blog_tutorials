# Chef Server Project

The goal of these area is to show how to bootstrap a Chef Server (or CINC Server) on systems managed by Vagrant (or other automation tools) and then converge two or more nodes by running the `chef-client` agent on each node.

## CINC Server

For this area, we’ll use CINC Server as an alternative to Chef Server, which is no longer available for free download. The latest open-source Chef Server version, `12.13.91`, was released over six years ago and only supports end-of-life distributions like Ubuntu 18.04 (EOL April 30, 2023) and CentOS 7 (EOL on June 30, 2024) ([source](https://community.chef.io/downloads/tools/infra-server)).

More recent versions, such as [Chef Infra Server 15.10.12](https://discourse.chef.io/t/chef-infra-server-15-10-12-released/23280), are behind a licensing paywall.

Given these limitations, [CINC Server](https://cinc.sh/) provides a practical solution for automating development and testing with a local Chef Server environment.



# Resources

These are links I have come across in research for this project.

* [Chef Server Provisioning](https://friendsofvagrant.github.io/v1/docs/provisioners/chef_server.html)
* [Linode Chef Articles](https://www.linode.com/docs/guides/applications/configuration-management/chef/)
  * [Install Chef on Ubuntu 20.04](https://www.linode.com/docs/guides/how-to-install-chef-on-ubuntu-20-04/)
  * [Installing a Chef Server Workstation on Ubuntu 18.04](https://www.linode.com/docs/guides/install-a-chef-server-workstation-on-ubuntu-18-04/)
* [Getting Started Managing Your Infrastructure Using Chef](https://www.digitalocean.com/community/tutorial-series/getting-started-managing-your-infrastructure-using-chef) - Digitial Ocean articles
  * [How To Set Up a Chef 12 Configuration Management System on Ubuntu 14.04 Servers](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-chef-12-configuration-management-system-on-ubuntu-14-04-servers)