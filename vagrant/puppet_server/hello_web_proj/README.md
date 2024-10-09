# Hello Web Project

## Instructions

1. Setup `bash setup.sh`
2. Launch Guests
   ```bash
   vagrant up --no-provision
   ```
3. Install Server
   ```bash
   vagrant provision puppetserver01 --provision-with "bootstrap"
   vagrant ssh puppetserver01 \
     --command "sudo /opt/puppetlabs/bin/puppetserver ca list --all"
   ```
4. Install Agents
   ```bash
   for NODE in node0{1..2}; do
     vagrant provision $NODE --provision-with "bootstrap"
   done
   ```
5. Issue Certificate Requests
   ```bash
   for NODE in node0{1..2}; do
     printf "\n$NODE: Testing connection (expect failure)\n"
     vagrant ssh $NODE --command 'sudo /opt/puppetlabs/bin/puppet agent --test'
   done
   ```
6. Verify
   ```bash
   vagrant ssh puppetserver01 --command "sudo /opt/puppetlabs/bin/puppetserver ca list"
   ```
7. Sign Certificates
   ```bash
   for NODE in node0{1..2}.local; do
     printf "\nSigning $NODE\n"
     vagrant ssh puppetserver01 --command \
       "sudo /opt/puppetlabs/bin/puppetserver ca sign --certname $NODE"
   done
   ```
8. Verify
   ```bash
   vagrant ssh puppetserver01 --command "sudo /opt/puppetlabs/bin/puppetserver ca list --all"
   ```
9. Test Connectivity
   ```bash
   for NODE in node0{1..2}; do
     printf "\n$NODE: Testing connection (expect success)\n"
     vagrant ssh $NODE --command 'sudo /opt/puppetlabs/bin/puppet agent --test'
   done
   ```
10. Provision
    ```bash
    for NODE in node0{1..2}; do vagrant provision $NODE; done
    ```
11. Test Results
    ```bash
    for NODE in node0{1..2}; do
      vagrant ssh $NODE --command "curl --include localhost"
    done
    ```
12. Cleanup
    ```bash
    vagrant destroy --force
    ```
