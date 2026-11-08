# Timings

How long each tutorial takes, measured with `bench.sh`. Each tutorial has one table: three
runs of every step, and their median, which keeps one slow or fast run from skewing the
result.

All runs were on an Apple M1 Max with 64 GB of memory and macOS 26.6.2, on
7 November 2026. The other tutorials haven't been timed yet.

## How to read the tables

| Step | Command |
| --- | --- |
| up, create and provision | `make up PROVISION=true`, with the image or box already downloaded |
| provision, no changes | `make provision` right after, so Ansible changes nothing |
| provision, page changed | `make provision` after editing `site/index.html` |
| provision or playbook, page restored | The same after putting the page back; `playbook` is `make playbook` |
| playbook, no changes | `make playbook`, run again |
| halt | `make halt` |
| up, from stopped | `make up` on the stopped VM |
| up, while running | `make up` when the VM is already running |
| destroy | `make destroy` |

The Ansible column shows the `changed` count from the play recap.

## Download cost

The first `make up` downloads the VM image or box, and that's often the slowest step. To
measure it, run 3 is a cold run: `bench.sh --cold` deletes the image or box with
`make purge`, times one `make up` that includes the download, then destroys the VM and
times a normal, warm `make up`. The download cost is the difference between the two. Each tutorial's section shows it
below its main table.

It's an estimate: it includes anything else the first run does differently, such as
unpacking or importing the image, and it depends on your connection. Each tutorial was
measured cold once.

## lima/ansible

Lima 2.2.1, ansible-core 2.21.5.

| Step | Run 1 | Run 2 | Run 3 | Median | Ansible |
| --- | ---: | ---: | ---: | ---: | --- |
| up, create and provision | 33.1s | 35.5s | 33.0s | 33.1s | changed=7 |
| provision, no changes | 3.4s | 3.5s | 3.3s | 3.4s | changed=0 |
| provision, page changed | 3.7s | 4.0s | 3.6s | 3.7s | changed=2 |
| provision, page restored | 3.7s | 3.8s | 3.6s | 3.7s | changed=2 |
| halt | 1.6s | 1.6s | 1.6s | 1.6s |  |
| up, from stopped | 6.1s | 6.3s | 6.1s | 6.1s |  |
| up, while running | 0.08s | 0.08s | 0.07s | 0.08s |  |
| destroy | 0.10s | 0.09s | 0.09s | 0.09s |  |

Download cost, from run 3 (after `make purge`):

| First `make up`, with download | Warm `make up`, same run | Download, estimated |
| ---: | ---: | ---: |
| 2m 17s | 33.0s | 1m 44s |

## vagrant/virtualbox/ansible

Vagrant 2.4.9, VirtualBox 7.2.22, ansible-core 2.21.5.

| Step | Run 1 | Run 2 | Run 3 | Median | Ansible |
| --- | ---: | ---: | ---: | ---: | --- |
| up, create and provision | 2m 55s | 2m 50s | 2m 48s | 2m 50s | changed=7 |
| provision, no changes | 6.2s | 5.9s | 5.6s | 5.9s | changed=0 |
| provision, page changed | 6.2s | 6.7s | 6.0s | 6.2s | changed=2 |
| playbook, page restored | 5.4s | 5.9s | 5.3s | 5.4s | changed=2 |
| playbook, no changes | 5.0s | 5.5s | 4.9s | 5.0s | changed=0 |
| halt | 3.2s | 3.4s | 3.2s | 3.2s |  |
| up, from stopped | 2m 16s | 2m 17s | 2m 16s | 2m 16s |  |
| up, while running | 1.6s | 1.6s | 1.6s | 1.6s |  |
| destroy | 3.2s | 3.2s | 3.2s | 3.2s |  |

Download cost, from run 3 (after `make purge`):

| First `make up`, with download | Warm `make up`, same run | Download, estimated |
| ---: | ---: | ---: |
| 7m 54s | 2m 48s | 5m 6s |
