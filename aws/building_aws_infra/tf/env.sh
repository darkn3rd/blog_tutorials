export AWS_DEFAULT_PROFILE="learning"
export AWS_PROFILE=$AWS_DEFAULT_PROFILE
export TF_VAR_profile=$AWS_DEFAULT_PROFILE
export TF_VAR_region=$(
  awk -F'= ' '/region/{print $2}' <(
    grep -A1 "\[.*$AWS_PROFILE\]" ~/.aws/config)
)