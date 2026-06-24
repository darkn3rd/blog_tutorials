# aws_cli - run AWS CLI using configured profile and region
aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$EKS_REGION" "$@"
}

# tag_spec - generate AWS tag-specifications argument
tag_spec() {
  local resource_type="$1"
  local tags="$2"
  printf "ResourceType=%s,Tags=[%s]" "$resource_type" "$tags"
}

# az_suffix - convert AZ name to uppercase identifier without dashes
# Example: us-east-2a -> USEAST2A
az_suffix() {
  local az="$1"
  echo "${az^^}" | tr -d '-'
}
# aws_text_exists - test whether AWS CLI text output contains a real value
# Returns false for empty string, None, or null.
aws_text_exists() {
  local value="${1:-}"
  [[ -n "$value" && "$value" != "None" && "$value" != "null" ]]
}

# aws_text_or_empty - normalize AWS CLI text output
# Returns the value only if it is not empty, None, or null.
aws_text_or_empty() {
  local value="${1:-}"
  aws_text_exists "$value" && printf '%s\n' "$value"
  return 0
}

# safety_checks - verify AWS credentials are valid
safety_checks() {
  log "Checking AWS caller identity"
  aws_cli sts get-caller-identity >/dev/null || die "AWS caller identity check failed"
}
