#!/usr/bin/env bash
command -v wget || { echo "Error: 'wget' command not found" >&2; return 1; }
command -v jq || { echo "Error: 'jq' command not found" >&2; return 1; }

[[ -f /etc/os-release ]] \
  && grep -iEq 'ubuntu|debian' /etc/os-release \
  || { echo "Error: Not running Debian or Ubuntu system >&2; return 1; }


LATEST=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest \
  | jq -r '.tag_name'
)

wget https://dl.step.sm/gh-release/cli/docs-cli-install/$LATEST/step-cli_${LATEST##v}_amd64.deb
sudo dpkg -i step-cli_${LATEST##v}_amd64.deb
