die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  printf '\n[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}
require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "required command '$cmd' not found in PATH"
}

require_env() {
  local var="$1"
  [[ -n "${!var:-}" ]] || die "environment variable '$var' is required"
}

require_commands() {
  local cmd
  for cmd in "$@"; do
    require_command "$cmd"
  done
}

require_envs() {
  local var
  for var in "$@"; do
    require_env "$var"
  done
}
