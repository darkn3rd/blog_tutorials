variable "arch" {
  type        = string
  description = "CPU architecture of the box: arm64 (Apple silicon) or amd64 (Intel/AMD). Must match the build host."

  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "arch must be \"amd64\" or \"arm64\"."
  }
}

variable "ubuntu_version" {
  type        = string
  description = "Ubuntu release, as it appears in the ISO file name (e.g. 26.04.1)."
  default     = "26.04.1"
}

# Where the build VM disk and the final .box go. Point it at an external drive
# to keep multi-GB build artifacts off the internal disk.
variable "build_dir" {
  type    = string
  default = "."
}

variable "headless" {
  type    = bool
  default = false
}
