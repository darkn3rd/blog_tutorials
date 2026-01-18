#!/usr/bin/env bash

main() {
  install_krew

  # Add this in your startup scripts 
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
}

install_krew() {
  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR

  OS="$(uname | tr '[:upper:]' '[:lower:]')"
  ARCH="$(
    uname -m \
    | sed -e 's/x86_64/amd64/' \
          -e 's/\(arm\)\(64\)\?.*/\1\2/' \
          -e 's/aarch64$/arm64/'
  )"
  KREW="krew-${OS}_${ARCH}"
  PKG="/${KREW}.tar.gz"
  URL_PATH="kubernetes-sigs/krew/releases/latest/download/$PKG"
  URL="https://github.com/$URL_PATH"
  curl -fsSLO "$URL"
  tar zxvf "${KREW}.tar.gz"
  ./"${KREW}" install krew

  popd
  rm -rf TEMP_DIR
}

main
