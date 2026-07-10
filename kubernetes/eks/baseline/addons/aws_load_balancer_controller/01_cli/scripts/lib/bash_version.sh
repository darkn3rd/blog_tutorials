#!/usr/bin/env bash
# lib/bash_version.sh — Checks the running bash meets this project's minimum
# version. This project targets modern bash + GNU/POSIX tooling only.
# Source this file; do not execute it directly.
#
# Assumes: die() is defined by the sourcing script.

MIN_BASH_MAJOR=4
MIN_BASH_MINOR=3

# verify_bash
# Exits via die() if the running bash is older than
# $MIN_BASH_MAJOR.$MIN_BASH_MINOR.
verify_bash() {
  (( BASH_VERSINFO[0] > MIN_BASH_MAJOR ||
     (BASH_VERSINFO[0] == MIN_BASH_MAJOR && BASH_VERSINFO[1] >= MIN_BASH_MINOR) )) \
    || die "This script requires bash >= ${MIN_BASH_MAJOR}.${MIN_BASH_MINOR}, found ${BASH_VERSION}."
}
