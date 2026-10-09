# ==================================================================================================
# File:        main.tf
# Module:      terraform-org-level-policy-gcp (repo)
# Description: Enables the Org Policy API and enforces the organization-wide security baseline: 
#              seven boolean constraints, plus allowed IAM member domains, denied VM external IPs, 
#              and allowed resource locations. 
# ==================================================================================================
#
# Change History
# --------------------------------------------------------------------------------------------------
# Date        Author                     Version  Description
# ----------  -------------------------  -------  --------------------------------------------------
# 2026-10-08  Steve Hager                1.0.0    Initial creation.
# YYYY-MM-DD  <name>                     x.y.z    <what changed and why>
# --------------------------------------------------------------------------------------------------
locals {
  org_parent = "organizations/${var.org_id}"
}

# ---------------------------------------------------------------------------
# API enablement
# ---------------------------------------------------------------------------
resource "google_project_service" "orgpolicy" {
  project            = var.billing_project
  service            = "orgpolicy.googleapis.com"
  disable_on_destroy = false
}

# this import is to be "one time" and removed after apply and before commit.
#import {
#  to = google_org_policy_policy.allowed_policy_member_domains[0]
#  id = "organizations/822574087702/policies/iam.allowedPolicyMemberDomains"
#}
# ---------------------------------------------------------------------------
# Boolean constraints (enforced = TRUE at the organization)
#
#   compute.skipDefaultNetworkCreation             - no "default" VPC in new projects
#   compute.requireOsLogin                         - IAM-based SSH via OS Login
#   iam.disableServiceAccountKeyCreation           - no downloadable SA keys
#   iam.automaticIamGrantsForDefaultServiceAccounts - default SAs don't get Editor
#   storage.uniformBucketLevelAccess               - no per-object ACLs
#   storage.publicAccessPrevention                 - no public buckets/objects
#   sql.restrictPublicIp                           - no public IPs on Cloud SQL
# ---------------------------------------------------------------------------
resource "google_org_policy_policy" "boolean" {
  for_each = toset(var.enforced_boolean_constraints)

  name   = "${local.org_parent}/policies/${each.value}"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

# ---------------------------------------------------------------------------
# List constraints
# ---------------------------------------------------------------------------

# Only identities from these Workspace/Cloud Identity customers may be granted
# IAM roles. Also blocks allUsers / allAuthenticatedUsers.
resource "google_org_policy_policy" "allowed_policy_member_domains" {
  count = length(var.allowed_customer_ids) > 0 ? 1 : 0

  name   = "${local.org_parent}/policies/iam.allowedPolicyMemberDomains"
  parent = local.org_parent

  spec {
    rules {
      values {
        allowed_values = var.allowed_customer_ids
      }
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

# No VM instance may have an external IP address.
resource "google_org_policy_policy" "vm_external_ip_access" {
  count = var.deny_vm_external_ips ? 1 : 0

  name   = "${local.org_parent}/policies/compute.vmExternalIpAccess"
  parent = local.org_parent

  spec {
    rules {
      deny_all = "TRUE"
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

# Regional/zonal resources may only be created in these locations.
# Global resources are not affected.
resource "google_org_policy_policy" "resource_locations" {
  count = length(var.allowed_locations) > 0 ? 1 : 0

  name   = "${local.org_parent}/policies/gcp.resourceLocations"
  parent = local.org_parent

  spec {
    rules {
      values {
        allowed_values = var.allowed_locations
      }
    }
  }

  depends_on = [google_project_service.orgpolicy]
}
