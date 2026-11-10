# Multi-machine Vagrant and Ansible on macOS

This project uses Vagrant to create four Ubuntu virtual machines on one private network,
and Ansible to configure them as a group. Vagrant runs with its default provider,
VirtualBox.

```
                      your Mac
                         |
              localhost:8080 -> lb:80
                         |
             +-----------+-----------+
             |  lb  192.168.56.10    |   HAProxy
             +-----------+-----------+
                         |
       +-----------------+-----------------+
       |                 |                 |
+------+------+   +------+------+   +------+------+
| web1  .11   |   | web2  .12   |   | web3  .13   |   nginx
+-------------+   +-------------+   +-------------+
```

The three app servers each serve a page showing their own hostname, IP address and
system details, in the style of a terminal system-info tool. The load balancer passes
each request to the next app server in turn, so reloading the page shows a different
server each time.

## Requirements

- macOS on Apple Silicon or Intel
- [Vagrant](https://developer.hashicorp.com/vagrant)
- [VirtualBox](https://www.virtualbox.org/) 7.1 or later, for Apple Silicon support
- [Ansible](https://docs.ansible.com/)
- About 4 GiB of free memory, 1 GiB for each VM

Install them with Homebrew:

```bash
brew install --cask vagrant virtualbox
brew install ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Vagrantfile` | Defines the four VMs, their private IP addresses and the Ansible provisioner |
| `playbook.yaml` | The Ansible playbook: applies the `appserver` role to the app servers and the `haproxy` role to the load balancer |
| `roles/appserver/` | Installs nginx and writes the system info page |
| `roles/haproxy/` | Installs HAProxy and writes its config |
| `inventory.yaml` | The inventory for running `ansible-playbook` directly |
| `ansible.cfg` | Ansible settings |
| `Makefile` | Short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

Every VM runs the `bento/ubuntu-26.04` box with 1 CPU and 1 GiB of memory.

| VM | IP address | Ansible group | Runs |
| --- | --- | --- | --- |
| `web1` | 192.168.56.11 | `app` | nginx |
| `web2` | 192.168.56.12 | `app` | nginx |
| `web3` | 192.168.56.13 | `app` | nginx |
| `lb` | 192.168.56.10 | `loadbalancer` | HAProxy |

## Usage

| Make | mise | Runs |
| --- | --- | --- |
| `make up` | `mise run up` | `vagrant up --provider=virtualbox --no-provision` |
| `make up PROVISION=true` | `PROVISION=true mise run up` | `vagrant up --provider=virtualbox --provision` |
| `make provision` | `mise run provision` | `vagrant provision lb`, which configures all four VMs |
| `make playbook` | `mise run playbook` | `ansible-playbook playbook.yaml`, without Vagrant |
| `make verify` | `mise run verify` | Requests the page six times and prints which server answered |
| `make ssh VM=web1` | `VM=web1 mise run ssh` | `vagrant ssh web1`; without `VM`, logs into `lb` |
| `make status` | `mise run status` | `vagrant status` |
| `make halt` | `mise run halt` | `vagrant halt` |
| `make destroy` | `mise run destroy` | `vagrant destroy --force` |
| `make purge` | `mise run purge` | `vagrant box remove`, deleting the downloaded box |

The first `make up` downloads the box, which takes a while.

Create the VMs and configure them:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080> and reload the page a few times. Each reload shows the
next app server, with its own hostname, IP address and accent color.

From the terminal:

```bash
make verify
```

```
    <title>web1</title>
    <title>web2</title>
    <title>web3</title>
    <title>web1</title>
    <title>web2</title>
    <title>web3</title>
```

HAProxy's status page, at <http://localhost:8404>, lists the three app servers and
whether each is up.

The private network is reachable from your Mac too, so you can also open an app server
directly, skipping the load balancer: <http://192.168.56.11>.

## How the VMs are defined

A `Vagrantfile` with several `config.vm.define` blocks is a multi-machine environment.
Settings on `config.vm` apply to every VM, and settings inside a `define` block apply
to that VM only.

The app servers are listed in a hash at the top of the `Vagrantfile`, and a loop defines
one VM for each:

```ruby
APP_SERVERS = {
  "web1" => "192.168.56.11",
  "web2" => "192.168.56.12",
  "web3" => "192.168.56.13",
}
```

To add a fourth app server, add a line here, and to `inventory.yaml` if you run the
playbook directly. The HAProxy config picks it up on the next provision.

Each VM gets two network interfaces. The first is VirtualBox's NAT interface, which
Vagrant uses for SSH and which has the same address, 10.0.2.15, on every VM. The second
is the private network, `private_network` in the `Vagrantfile`, where each VM has its
own address and the VMs can reach one another. HAProxy talks to the app servers over the
private network.

Only `lb` forwards ports to your Mac: 8080 for the site and 8404 for the status page.

Most Vagrant commands take a VM name, such as `vagrant ssh web2` or `vagrant halt web3`.
Without one, they act on every VM.

## How provisioning works

There are two ways to run the playbook. Both put the VMs in the `app` and
`loadbalancer` groups, which are the groups the playbook targets, and both give each VM
a `private_ip` variable.

### Through Vagrant

The Ansible provisioner is attached only to `lb`, the last VM in the `Vagrantfile`, and
set to `ansible.limit = "all"`:

```ruby
lb.vm.provision "ansible" do |ansible|
  ansible.playbook = "playbook.yaml"
  ansible.limit = "all"
  ...
end
```

`vagrant up` creates the VMs in the order they're defined, so by the time `lb` is
provisioned, all four are running. Ansible then configures all four in one run, in
parallel. Had the provisioner been on every VM, Vagrant would run the playbook four
times, each time against a single VM, and HAProxy's config would be written before the
app servers existed.

That's also why `make provision` runs `vagrant provision lb`: provisioning `lb`
configures everything.

Vagrant's provisioner writes its own inventory. `ansible.groups` in the `Vagrantfile`
sets the groups, and `ansible.host_vars` sets `private_ip` for each VM.

### Directly with Ansible

`make playbook` runs Ansible without Vagrant's provisioner. It does two things:

```bash
vagrant ssh-config > .vagrant/ssh.config
ansible-playbook playbook.yaml
```

`vagrant ssh-config` prints the SSH settings for every VM: its address, port, user and
key. `inventory.yaml` passes that file to SSH and lists the same groups and `private_ip`
values as the `Vagrantfile`. `ansible.cfg` makes `inventory.yaml` the default inventory.

Once `.vagrant/ssh.config` exists, you can run other Ansible commands yourself, such as:

```bash
ansible all -m ping
ansible app -m command -a uptime
```

## The roles

The playbook has two plays, one per group, and each applies one role:

```yaml
- name: Configure the app servers
  hosts: app
  become: true
  roles:
    - appserver

- name: Configure the load balancer
  hosts: loadbalancer
  become: true
  roles:
    - haproxy
```

A role is a folder of tasks and the files they use. Ansible finds roles in the `roles/`
folder next to the playbook, and looks for each part in a fixed place:

```
roles/
├── appserver/
│   ├── tasks/main.yaml           install nginx, write the page
│   └── templates/index.html.j2   the system info page
└── haproxy/
    ├── tasks/main.yaml           install HAProxy, write its config
    ├── handlers/main.yaml        reload HAProxy when the config changes
    └── templates/haproxy.cfg.j2  the HAProxy config
```

### appserver

Before running any tasks, Ansible gathers *facts* about each VM: its hostname, OS,
kernel, CPU count, memory and more. The `template` task fills `index.html.j2` with those
facts and writes the result to `/var/www/html/index.html`, so every app server ends up
with a page about itself:

```html
<div><span class="key">Hostname</span>: {{ ansible_facts['hostname'] }}</div>
<div><span class="key">IP address</span>: {{ private_ip }}</div>
<div><span class="key">Kernel</span>: {{ ansible_facts['kernel'] }}</div>
```

The page is written when the playbook runs, so the values are a snapshot from that
moment. Run the playbook again without changing anything and Ansible reports
`changed=0`: the facts are the same, so the page is too.

To see every fact Ansible collects about a VM:

```bash
ansible web1 -m setup
```

### haproxy

The HAProxy config is also a template. It loops over the `app` group and adds one
`server` line per app server, using each one's `private_ip`:

```
backend app
    balance roundrobin
{% for host in groups['app'] %}
    server {{ host }} {{ hostvars[host]['private_ip'] }}:80 check
{% endfor %}
```

which becomes:

```
backend app
    balance roundrobin
    server web1 192.168.56.11:80 check
    server web2 192.168.56.12:80 check
    server web3 192.168.56.13:80 check
```

`balance roundrobin` sends each request to the next server in the list. `check` makes
HAProxy test each server regularly and stop sending it requests if it stops answering.

The task's `validate: haproxy -c -f %s` line checks the new config with HAProxy before
it replaces the old one, so a typo can't take the load balancer down. When the config
changes, the task notifies the `Reload HAProxy` handler.

## Trying a failure

Stop one app server and watch HAProxy route around it:

```bash
vagrant halt web2
make verify
```

HAProxy checks each server every 2 seconds and marks it down after 3 failed checks. Until
then, a request sent to `web2` fails, so `make verify` may print fewer than six lines.
After that, only `web1` and `web3` answer, and the status page at
<http://localhost:8404> shows `web2` as down. Bring it back:

```bash
vagrant up web2
```

## Cleaning up

```bash
make destroy
```

This deletes all four VMs. The downloaded box stays cached; to remove it as well:

```bash
make purge
```

## Troubleshooting

### Port 8080 or 8404 in use

If `vagrant up` stops because a port is already taken, find the process using it:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Either stop that process, or open the `Vagrantfile` and change the `host` value on the
`forwarded_port` line to a free port, such as `8081`.

### The private network address is refused

VirtualBox only allows host-only addresses in `192.168.56.0/21` by default. If you change
the IP addresses, keep them in that range, or list the range you want in
`/etc/vbox/networks.conf`.
