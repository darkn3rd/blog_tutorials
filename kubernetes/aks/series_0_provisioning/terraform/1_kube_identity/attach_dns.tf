##########
# attach_dns - this associates Azure DNS zone to the managed identity for the
#              VMSS of the default node  group.
#
# WARNING: Do NOT do this in produciton!!!
#          This allows ALL pods to access the Azure DNS Zone.  This is only used
#          for demonstration purposes for this tutorial.

# NOTE: See AAD Pod Identity to allow explicit pods to access the Azure DNS Zone
#       resource
##########################
resource "azurerm_role_assignment" "attach_dns" {
  count = var.enable_attach_dns ? 1 : 0

  scope                = module.dns.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = module.aks.kubelet_identity[0].object_id
}
