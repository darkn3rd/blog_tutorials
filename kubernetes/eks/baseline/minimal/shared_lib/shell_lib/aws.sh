aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$EKS_REGION" "$@"
}

tag_spec() {
  local resource_type="$1"
  local tags="$2"
  printf "ResourceType=%s,Tags=[%s]" "$resource_type" "$tags"
}

az_suffix() {
  local az="$1"
  echo "${az^^}" | tr -d '-'
}

aws_text_exists() {
  local value="${1:-}"
  [[ -n "$value" && "$value" != "None" && "$value" != "null" ]]
}

aws_text_or_empty() {
  local value="${1:-}"
  aws_text_exists "$value" && printf '%s\n' "$value"
}

safety_checks() {
  log "Checking AWS caller identity"
  aws_cli sts get-caller-identity >/dev/null
}
