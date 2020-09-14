#####################################################################
## Resources
#####################################################################
output "AccountName" {
  value = local.account_name
}

output "AccountKey" {
  value     = local.account_key
  sensitive = true
}

output "ResourceName" {
  value    = local.resource_name
}
