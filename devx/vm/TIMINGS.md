# Timings

<!-- Written by bench-all.sh from the *.timings.csv results. Don't edit by hand. -->

How long each step takes in each tutorial, measured with `bench-all.sh`. Each value is the median of that tutorial's runs, which keeps one slow or fast run from skewing it.

| Step | `lima/ansible` | `vagrant/virtualbox/ansible` |
| --- | ---: | ---: |
| Runs | 0 cold, 3 warm | 0 cold, 3 warm |
| `make provision`, no changes | 3.4s | 5.9s |
| `make provision`, page changed | 3.7s | 6.2s |
| `make provision`, page restored | 3.7s | – |
| `make playbook`, page restored | – | 5.4s |
| `make playbook`, no changes | – | 5.0s |
| `make halt` | 1.6s | 3.2s |
| `make up`, from stopped | 6.1s | 2m 16s |
| `make up`, while running | 0.08s | 1.6s |
| `make destroy` | 0.09s | 3.2s |

- **Creating and provisioning are timed separately.** `make up` creates and boots the VM without configuring it, and the first `make provision` configures it.
- **Download, estimated** is the cold `make up` minus the warm one. A cold run deletes the image or box with `make purge` first. The estimate also includes any other first-run work, such as unpacking the image, and it depends on your connection.
- **`make provision`** runs Vagrant's provisioner in the Vagrant tutorials and `ansible-playbook` from the Mac in the others. `make playbook` runs `ansible-playbook` from the Mac in the Vagrant tutorials.
- **Measured on** an Apple M1 Max with 64 GB of memory and macOS 26.6.2, 2026-11-07.
- **Not timed:** `vagrant/avf/ansible`, SSH to the VM fails in testing.
