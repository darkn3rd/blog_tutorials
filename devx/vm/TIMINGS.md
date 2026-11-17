# Timings

<!-- Written by bench-all.sh from the *.timings.csv results. Don't edit by hand. -->

How long each step takes in each tutorial, measured with `bench-all.sh`. Each value is the median of that tutorial's runs, which keeps one slow or fast run from skewing it.

| Step | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Runs | 1 cold, 3 warm | 1 cold, 3 warm | 1 cold, 3 warm | 1 cold, 3 warm | 1 cold, 3 warm | 1 cold, 3 warm |
| First `make up`, with download | 1m 50s | 2m 26s | 2m 47s | 2m 11s | 1m 53s | 1m 33s |
| Download, estimated | 1m 35s | 2m 10s | 2m 38s | 1m 42s | 1m 29s | 1m 15s |
| `make up`, create | 14.8s | 16.2s | 9.2s | 28.9s | 24.4s | 18.4s |
| `make provision`, first run | 3m 48s | 31.7s | 23.2s | 32.3s | 25.2s | 22.5s |
| `make provision`, no changes | 3.8s | 3.8s | 3.8s | 4.4s | 5.2s | 4.0s |
| `make provision`, page changed | 4.1s | 4.3s | 4.2s | 4.9s | 5.5s | 4.5s |
| `make provision`, page restored | 4.1s | 4.2s | 4.3s | 4.8s | – | – |
| `make playbook`, page restored | – | – | – | – | 4.8s | 4.2s |
| `make playbook`, no changes | – | – | – | – | 4.4s | 3.8s |
| `make halt` | 1.6s | 2.1s | 2.1s | 6.3s | 3.1s | 2.6s |
| `make up`, from stopped | 6.3s | 14.9s | 6.9s | 22.3s | 19.7s | 17.6s |
| `make up`, while running | 0.07s | 0.45s | 0.44s | 2.4s | 1.5s | 0.54s |
| `make destroy` | 0.10s | 0.07s | 0.09s | 6.7s | 2.7s | 2.6s |

- **Creating and provisioning are timed separately.** `make up` creates and boots the VM without configuring it, and the first `make provision` configures it.
- **Download, estimated** is the cold `make up` minus the warm one. A cold run deletes the image or box with `make purge` first. The estimate also includes any other first-run work, such as unpacking the image, and it depends on your connection.
- **`make provision`** runs Vagrant's provisioner in the Vagrant tutorials and `ansible-playbook` from the Mac in the others. `make playbook` runs `ansible-playbook` from the Mac in the Vagrant tutorials.
- **Measured on** an Apple M1 Max with 64 GB of memory and macOS 26.6.2, 2026-11-09 to 2026-11-16.
- **Not timed:** `vagrant/avf/ansible`, SSH to the VM fails in testing.
