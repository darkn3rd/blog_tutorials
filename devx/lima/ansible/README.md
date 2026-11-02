# Lima and Ansible

An Ubuntu LTS VM on macOS, created by [Lima](https://lima-vm.io/) and configured by
Ansible from the host.

## Requirements

```bash
brew install lima ansible
```

## Usage

```bash
make up         # download vm image and launch vm
make provision  # run ansible playbook on guest
make test       # run curl to verify
make ssh        # log into guest
make halt       # shutdown guest
make destroy    # destory vm 
```

Note that luanching the system will not automatically provision the systems.  To enable this by default, set `PROVISION=true`

```bash
PROVISION=true make up
```

## Measured results

One run of each step, not a benchmark. Host: Apple Silicon Mac on macOS 26 (Darwin 25.6),
Lima 2.2.1, ansible-core 2.21.5, tested 2026-11-01. These runs predate the `PROVISION`
switch, when `make up` always ran the playbook, so every `make up` time here includes it.
The tables below were measured before nginx was added, except where noted.

| Step | Time |
| --- | --- |
| First `make up`, including image download | About 3m 15s |
| `make up` after `make destroy`, image cached | 33s |
| The same step with the nginx-only playbook | 38s |
| `make up` from stopped | 9s |
| `make up` while running | 3s |
| `make provision` with nothing to change | 3s |
| `make halt` | 1s |
| `make destroy` | Under 1s |

| Check | Result |
| --- | --- |
| Guest OS | Ubuntu 26.04.1 LTS, kernel 7.0.0-34-generic, aarch64 |
| VM backend | `vz` (Apple Virtualization.framework), Lima's choice on this host |
| `/workspace` mount | virtiofs, writable from the guest and visible on the host |
| Second playbook run | `changed=0` |
| Instance size on disk | 2.5 GB in `~/.lima/dev` |
| Lima download cache | 3.3 GB in `~/Library/Caches/lima` |

Handler behaviour, measured with nginx 1.28.3:

| Action | Handler | nginx master PID | nginx worker PIDs |
| --- | --- | --- | --- |
| Edit the page, then `make provision` | Ran | 1084, unchanged | 1085 and 1086 replaced by 2144 and 2145 |
| `make provision` with no edit | Skipped | 1084, unchanged | 2144 and 2145, unchanged |
