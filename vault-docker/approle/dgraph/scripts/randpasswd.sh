randpasswd() {
  NUM=${1:-32}

  # macOS scenario
  if [[ $(uname -s) == "Darwin" ]]; then
    perl -pe 'binmode(STDIN, ":bytes"); tr/A-Za-z0-9//dc;' < /dev/urandom | head -c $NUM
  else
    # tested with: GNU/Linux, Cygwin, MSys
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w $NUM | sed 1q
  fi
}

NUM=${1:-32}

randpasswd $NUM