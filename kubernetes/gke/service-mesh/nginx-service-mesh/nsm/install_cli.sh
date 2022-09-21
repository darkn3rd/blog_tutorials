pushd ~/Downloads
if [[ "$(uname -s)" == "Linux" ]]; then
  [[ -f nginx-meshctl_linux.gz ]] && gunzip nginx-meshctl_linux.gz
  sudo mv nginx-meshctl_linux /usr/local/bin/nginx-meshctl
  sudo chmod +x /usr/local/bin/nginx-meshctl
elif  [[ "$(uname -s)" == "Darwin" ]]; then
  [[ -f nginx-meshctl_darwin.gz ]] && gunzip nginx-meshctl_darwin.gz
  sudo mv nginx-meshctl_darwin /usr/local/bin/nginx-meshctl
  sudo chmod +x /usr/local/bin/nginx-meshctl
fi
popd
