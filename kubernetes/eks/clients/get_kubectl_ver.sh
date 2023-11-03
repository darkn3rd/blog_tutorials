VER=$(kubectl version --short 2> /dev/null \
  | grep Server \
  | grep -oP '(\d{1,2}\.){2}\d{1,2}'
)

# setup kubectl tool
asdf install kubectl $VER
asdf global kubectl $VER
