# Shared Components

This directory contains components shared by the examples in the `minimal_eks` project.

The goal is to reduce duplication between the EKS examples while keeping each example focused on the concepts it is intended to demonstrate.

## Layout

```text
shared_lib/
├── scripts
├── shell_lib
└── terraform
    └── modules
```

### scripts

Standalone utility scripts used by one or more examples.

### shell_lib

Reusable shell functions intended to be sourced by scripts and examples.

### terraform/modules

Reusable Terraform modules shared by the Terraform-based examples.

## Scope

The contents of this directory are intended only for the `minimal_eks` examples and are not designed to be a general-purpose framework.

Whenever practical, examples remain self-contained to make them easier to read and understand.
