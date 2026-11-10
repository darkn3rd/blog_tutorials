# Timings

<!-- Written by bench-all.sh from the *.timings.csv results. Don't edit by hand. -->

How long each step takes in each tutorial, measured with `bench-all.sh`. Each value is the median of that tutorial's runs, which keeps one slow or fast run from skewing it.

| Step | `lima/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | ---: | ---: | ---: |
| Runs | 1 cold, 3 warm | 1 cold, 3 warm | 1 cold, 3 warm |
| First `make up`, with download | 1m 50s | 7m 39s | 7m 53s |
| Download, estimated | 1m 35s | 5m 6s | 5m 38s |
| `make up`, create | 14.8s | 2m 32s | 2m 15s |
| `make provision`, first run | 3m 48s | 3m 31s | 3m 6s |
| `make provision`, no changes | 3.8s | 43.6s | 7.0s |
| `make provision`, page changed | 4.1s | 44.0s | 1m 7s |
| `make provision`, page restored | 4.1s | – | – |
| `make playbook`, page restored | – | 9.5s | 1m 9s |
| `make playbook`, no changes | – | 39.8s | 34.5s |
| `make halt` | 1.6s | 4.3s | 1.7s |
| `make up`, from stopped | 6.3s | 2m 18s | 2m 14s |
| `make up`, while running | 0.07s | 2.4s | 0.59s |
| `make destroy` | 0.10s | 3.9s | 1.7s |

- **Creating and provisioning are timed separately.** `make up` creates and boots the VM without configuring it, and the first `make provision` configures it.
- **Download, estimated** is the cold `make up` minus the warm one. A cold run deletes the image or box with `make purge` first. The estimate also includes any other first-run work, such as unpacking the image, and it depends on your connection.
- **`make provision`** runs Vagrant's provisioner in the Vagrant tutorials and `ansible-playbook` from the Mac in the others. `make playbook` runs `ansible-playbook` from the Mac in the Vagrant tutorials.
- **Measured on** an Apple M1 Max with 64 GB of memory and macOS 26.6.2, 2026-11-09.
- **Not timed:** `vagrant/avf/ansible`, SSH to the VM fails in testing.
