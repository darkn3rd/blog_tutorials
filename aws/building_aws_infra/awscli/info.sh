
aws rds describe-db-instances \
  --filters "Name=db-instance-id,Values=$USER-db" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text

