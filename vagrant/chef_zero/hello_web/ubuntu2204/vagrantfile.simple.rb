Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  config.vm.network "forwarded_port", guest: 80, host: 8085

  config.vm.provision "chef_zero" do |chef|
    chef.cookbooks_path = "../cookbooks"
    chef.add_recipe "hello_web"
    chef.nodes_path = "nodes"

    chef.log_level = "debug"
    chef.arguments = "--chef-license accept-silent"
  end
end
