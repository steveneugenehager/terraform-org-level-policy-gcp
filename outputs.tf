# ==================================================================================================
# File:        outputs.tf
# Module:      terraform-org-level-policy-gcp (repo)
# Description: Outputs the full resource names of every organization policy this repo manages.
# ==================================================================================================
#
# Change History
# --------------------------------------------------------------------------------------------------
# Date        Author                     Version  Description
# ----------  -------------------------  -------  --------------------------------------------------
# 2026-10-08  Steve Hager                1.0.0    Initial creation.
# 2026-10-09  Steve Hager                1.1.0    Added the host project no-VM policy to
#                                                   managed_policies; added host_project_tag_value.
# YYYY-MM-DD  <name>                     x.y.z    <what changed and why>
# --------------------------------------------------------------------------------------------------
output "managed_policies" {
  description = "Full resource names of every org policy managed by this repo."
  value = concat(
    [for p in google_org_policy_policy.boolean : p.name],
    google_org_policy_policy.allowed_policy_member_domains[*].name,
    google_org_policy_policy.vm_external_ip_access[*].name,
    google_org_policy_policy.resource_locations[*].name,
    google_org_policy_policy.no_vms_in_host_projects[*].name,
  )
}

output "host_project_tag_value" {
  description = "Tag value ID (tagValues/NNN) to bind to Shared VPC host projects. Pass it to terraform-network-project-setup-gcp as host_project_tag_value."
  value       = one(google_tags_tag_value.shared_vpc_host[*].id)
}
