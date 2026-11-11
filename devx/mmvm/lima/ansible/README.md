# Multi-machine Lima and Ansible on macOS

This project uses Lima to create four Ubuntu virtual machines on one shared network, and
Ansible to configure them as a group.

```
                      your Mac
                         |
              localhost:8080 -> lb:80
                         |
             +-----------+-----------+
             |  lb                   |   HAProxy
             +-----------+-----------+
                         |   user-v2 network, 192.168.104.0/24
       +-----------------+-----------------+
       |                 |                 |
+------+------+   +------+------+   +------+------+
|    web1     |   |    web2     |   |    web3     |   nginx
+-------------+   +-------------+   +-------------+
```

The three app servers each serve a page showing their own hostname, IP address and
system details, in the style of a terminal system-info tool. The load balancer passes
each request to the next app server in turn, so reloading the page shows a different
server each time.

## Requirements

- macOS on Apple Silicon or Intel
- [Lima](https://lima-vm.io/) 2.0 or later
- [Ansible](https://docs.ansible.com/)
- About 4 GiB of free memory, 1 GiB for each VM

Install them with Homebrew:

```bash
brew install lima ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `lima/appserver.yaml` | The Lima template for `web1`, `web2` and `web3` |
| `lima/loadbalancer.yaml` | The Lima template for `lb`, which also forwards ports to the Mac |
| `playbook.yaml` | The Ansible playbook: applies the `appserver` role to the app servers and the `haproxy` role to the load balancer |
| `roles/appserver/` | Installs nginx and writes the system info page |
| `roles/haproxy/` | Installs HAProxy and writes its config |
| `inventory.yaml` | Lists the VMs and their groups, and tells Ansible how to reach them |
| `ansible.cfg` | Ansible settings |
| `Makefile` | Short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

Every VM runs the newest Ubuntu LTS image known to your Lima version, with 1 CPU, 1 GiB
of memory and a 10 GiB disk.

| VM | Host name | Ansible group | Runs |
| --- | --- | --- | --- |
| `web1` | `lima-web1` | `app` | nginx |
| `web2` | `lima-web2` | `app` | nginx |
| `web3` | `lima-web3` | `app` | nginx |
| `lb` | `lima-lb` | `loadbalancer` | HAProxy |

## Usage

| Make | mise | Runs |
| --- | --- | --- |
| `make up` | `mise run up` | `limactl start` for each VM |
| `make up PROVISION=true` | `PROVISION=true mise run up` | `limactl start` for each VM, then `make provision` |
| `make provision` | `mise run provision` | `ansible-playbook playbook.yaml`, which configures all four VMs |
| `make verify` | `mise run verify` | Requests the page six times and prints which server answered |
| `make ssh VM=web1` | `VM=web1 mise run ssh` | `limactl shell web1`; without `VM`, logs into `lb` |
| `make status` | `mise run status` | `limactl list` for the four VMs |
| `make halt` | `mise run halt` | `limactl stop` for each VM |
| `make destroy` | `mise run destroy` | `limactl delete --force` for the four VMs |
| `make purge` | `mise run purge` | `limactl prune`, deleting Lima's downloaded images |

The first `make up` downloads the Ubuntu image, which takes a while. The other three VMs
reuse it.

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
    <title>lima-web1</title>
    <title>lima-web2</title>
    <title>lima-web3</title>
    <title>lima-web1</title>
    <title>lima-web2</title>
    <title>lima-web3</title>
```

HAProxy's status page, at <http://localhost:8404>, lists the three app servers and
whether each is up.

The app servers aren't reachable from your Mac directly; everything goes through the load
balancer. To check one app server on its own, ask it from inside the VM:

```bash
limactl shell web1 curl -s localhost
```

## How the VMs are defined

Lima creates one VM, which it calls an instance, from one template file. There's no
single file that describes several VMs, so this project has two templates and starts
four instances from them:

```bash
limactl start --name=web1 lima/appserver.yaml
limactl start --name=web2 lima/appserver.yaml
limactl start --name=web3 lima/appserver.yaml
limactl start --name=lb   lima/loadbalancer.yaml
```

`make up` runs these in a loop. Once an instance exists, Lima keeps its own copy of the
template in `~/.lima/<name>/lima.yaml`, so `make up` runs `limactl start <name>` instead,
and changes to the templates only apply after `make destroy up`.

The two templates are the same except for `portForwards`:

```yaml
# lima/loadbalancer.yaml
portForwards:
- guestPort: 80
  hostPort: 8080
- guestPort: 8404
  hostPort: 8404
- guestPortRange: [1, 65535]
  ignore: true
```

By default Lima forwards every port a VM listens on to the same port on the Mac. With
three app servers all listening on port 80, they'd compete for it. Lima uses the first
rule that matches a port, so the app servers' template has only the `ignore` rule, and
the load balancer forwards ports 80 and 8404 and ignores the rest.

### Networking

By default, Lima gives each VM a private network of its own, with the same address,
192.168.5.15, on every VM. The VMs can't reach one another on it. This part of the
templates replaces it with a network the VMs share:

```yaml
networks:
- lima: user-v2
```

`user-v2` is a network Lima runs itself, without needing root, defined in
`~/.lima/_config/networks.yaml` as `192.168.104.0/24`. Each VM gets an address on it,
the VMs can reach one another by address or by the name `lima-<instance>.internal`, and
HAProxy talks to the app servers on it. Your Mac isn't on this network; it reaches the
VMs through Lima's SSH connections and port forwards.

Lima hands out the addresses on this network, so they're not known until the VMs are
running, and can change if a VM is recreated. That's why the inventory reads them from
Ansible's facts instead of listing them.

## How provisioning works

`make provision` runs `ansible-playbook playbook.yaml` from your Mac. `ansible.cfg`
makes `inventory.yaml` the default inventory, which lists the VMs in two groups:

```yaml
children:
  app:
    hosts:
      lima-web1:
      lima-web2:
      lima-web3:
  loadbalancer:
    hosts:
      lima-lb:
```

Lima writes an SSH config for each instance, such as `~/.lima/web1/ssh.config`, with the
host alias `lima-web1`. The inventory tells SSH to use the matching file:

```yaml
lima_instance: "{{ inventory_hostname | replace('lima-', '') }}"
ansible_ssh_common_args: '-F "{{ lima_home }}/{{ lima_instance }}/ssh.config"'
```

and defines each VM's `private_ip` as its default IPv4 address, which is its address on
the shared network:

```yaml
private_ip: "{{ ansible_facts['default_ipv4']['address'] }}"
```

Ansible works out a variable like this when it's used, for the host it's used for, so
`web1` gets `web1`'s address and `web2` gets `web2`'s.

Once the VMs are running, you can run other Ansible commands yourself, such as:

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
kernel, CPU count, memory, network interfaces and more. The `template` task fills
`index.html.j2` with those facts and writes the result to `/var/www/html/index.html`, so
every app server ends up with a page about itself:

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
ansible lima-web1 -m setup
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

which becomes something like:

```
backend app
    balance roundrobin
    server lima-web1 192.168.104.1:80 check
    server lima-web2 192.168.104.3:80 check
    server lima-web3 192.168.104.4:80 check
```

`hostvars[host]` reads another host's variables. Here it reads the address from
facts gathered about the app servers in the first play, which is why the playbook
configures the app servers first. Run the `haproxy` role on its own, with
`--limit loadbalancer`, and those facts aren't there.

`balance roundrobin` sends each request to the next server in the list. `check` makes
HAProxy test each server regularly and stop sending it requests if it stops answering.

The task's `validate: haproxy -c -f %s` line checks the new config with HAProxy before
it replaces the old one, so a typo can't take the load balancer down. When the config
changes, the task notifies the `Reload HAProxy` handler.

## Trying a failure

Stop one app server and watch HAProxy route around it:

```bash
limactl stop web2
make verify
```

HAProxy checks each server every 2 seconds and marks it down after 3 failed checks. Until
then, a request sent to `web2` fails, so `make verify` may print fewer than six lines.
After that, only `lima-web1` and `lima-web3` answer, and the status page at
<http://localhost:8404> shows `lima-web2` as down. Bring it back:

```bash
limactl start web2
```

If `web2` comes back with a different address, run `make provision` to update HAProxy.

## Cleaning up

```bash
make destroy
```

This deletes all four VMs. Lima keeps the downloaded image cached; to remove it as well:

```bash
make purge
```

## Troubleshooting

### Port 8080 or 8404 in use

If the site doesn't load, check whether another process is using the port:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Either stop that process, or change `hostPort` in `lima/loadbalancer.yaml` to a free
port, such as `8081`, then recreate the load balancer:

```bash
limactl delete --force lb
make up PROVISION=true
```

### An instance name is already taken

Lima instance names are shared by everything on your Mac that uses Lima. If you already
have an instance called `web1`, `web2`, `web3` or `lb`, `make up` starts that one instead
of creating a new one. Check with `limactl list`.
