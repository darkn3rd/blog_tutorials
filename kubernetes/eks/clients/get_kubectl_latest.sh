# install kubectl plugin for asdf
asdf plugin-add kubectl \
  https://github.com/asdf-community/asdf-kubectl.git
asdf install kubectl latest

# fetch latest kubectl
asdf install kubectl latest
asdf global kubectl latest
