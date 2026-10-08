output "managed_policies" {
  description = "Full resource names of every org policy managed by this repo."
  value = concat(
    [for p in google_org_policy_policy.boolean : p.name],
    google_org_policy_policy.allowed_policy_member_domains[*].name,
    google_org_policy_policy.vm_external_ip_access[*].name,
    google_org_policy_policy.resource_locations[*].name,
  )
}
