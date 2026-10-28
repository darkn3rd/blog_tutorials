packer {
  required_plugins {
    virtualbox = {
      version = "1.1.3"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = "1.1.6"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}
