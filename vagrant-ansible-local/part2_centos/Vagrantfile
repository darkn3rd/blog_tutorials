Vagrant.configure("2") do |config|
  config.vm.box = "bento/centos-7.5"
  config.vm.network "forwarded_port", guest: 80, host: 8086
  ####### Provision #######
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "provision/playbook.yml"
    ansible.verbose = true
    ansible.extra_vars = {
      hello_web: {
        package: "httpd",
        service: "httpd",
        docroot: "/var/www/html"
      }
    }
  end
end
