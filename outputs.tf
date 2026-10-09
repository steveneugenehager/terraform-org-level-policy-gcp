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
# YYYY-MM-DD  <name>                     x.y.z    <what changed and why>
# --------------------------------------------------------------------------------------------------
output "managed_policies" {
  description = "Full resource names of every org policy managed by this repo."
  value = concat(
    [for p in google_org_policy_policy.boolean : p.name],
    google_org_policy_policy.allowed_policy_member_domains[*].name,
    google_org_policy_policy.vm_external_ip_access[*].name,
    google_org_policy_policy.resource_locations[*].name,
  )
}
