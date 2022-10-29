#!/usr/bin/env bash
#############################
# fetch_step_cli.sh
# Description:
#  Script to install Step CLI based on https://smallstep.com/docs/step-cli/installation
#############################
command -v jq || { echo "Error: 'jq' command not found" >&2; return 1; }

LATEST=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest \
  | jq -r '.tag_name'
)

if [[ "$(uname -s)" == "Linux" ]]; then
  if [[ -f /etc/os-release ]] && grep -iEq 'ubuntu|debian' /etc/os-release; then
    command -v wget || { echo "Error: 'wget' command not found" >&2; return 1; }
    pushd ~/Downloads
    wget https://dl.step.sm/gh-release/cli/docs-cli-install/$LATEST/step-cli_${LATEST##v}_amd64.deb
    sudo dpkg -i step-cli_${LATEST##v}_amd64.deb
    popd
  else
    { echo "Error: Not running Debian or Ubuntu system. Aborting." >&2; return 1; }
  fi
elif [[ "$(uname -s)" == "Darwin" ]]; then
  command -v brew || { echo "Error: Homebrew (https://brew.sh/) not installed. Aborting." >&2; return 1; }
  brew install step
fi
