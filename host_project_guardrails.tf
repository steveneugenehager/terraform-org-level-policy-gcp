# ==================================================================================================
# File:        host_project_guardrails.tf
# Module:      terraform-org-level-policy-gcp (repo)
# Description: Keeps Shared VPC host projects network-only: a "purpose: shared-vpc-host" tag, and an
#              org-wide custom constraint that denies VM creation only in projects carrying that tag.
# ==================================================================================================
#
# Change History
# --------------------------------------------------------------------------------------------------
# Date        Author                     Version  Description
# ----------  -------------------------  -------  --------------------------------------------------
# 2026-10-09  Steve Hager                1.0.0    Initial creation.
# YYYY-MM-DD  <name>                     x.y.z    <what changed and why>
# --------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Tag that marks a project as a Shared VPC host. terraform-network-project-setup-gcp
# binds it to each host project, wherever that project sits in the folder tree.
# ---------------------------------------------------------------------------
resource "google_tags_tag_key" "host" {
  count = var.host_project_no_vms ? 1 : 0

  parent      = local.org_parent
  short_name  = var.host_tag_key
  description = "What a project is for. Policies and firewall rules can key off it."
}

resource "google_tags_tag_value" "shared_vpc_host" {
  count = var.host_project_no_vms ? 1 : 0

  parent      = google_tags_tag_key.host[0].id
  short_name  = var.host_tag_value
  description = "Shared VPC host project: networking only, no VMs."
}

# Who may bind the tag to projects (the Terraform SA that creates host projects).
resource "google_tags_tag_value_iam_member" "host_tag_users" {
  for_each = var.host_project_no_vms ? toset(var.host_tag_users) : toset([])

  tag_value = google_tags_tag_value.shared_vpc_host[0].id
  role      = "roles/resourcemanager.tagUser"
  member    = each.value
}

# ---------------------------------------------------------------------------
# Custom constraint: deny creating any VM instance (covers GKE nodes and
# VM-based appliances too). Defined once; it does nothing until enforced.
# ---------------------------------------------------------------------------
resource "google_org_policy_custom_constraint" "deny_compute_instances" {
  count = var.host_project_no_vms ? 1 : 0

  parent       = local.org_parent
  name         = "custom.denyComputeInstances"
  display_name = "Deny Compute Engine VM instances"
  description  = "Blocks VM creation. Enforced only where the shared-vpc-host tag is bound."

  resource_types = ["compute.googleapis.com/Instance"]
  method_types   = ["CREATE"]
  condition      = "resource.name.size() > 0" # true for every instance
  action_type    = "DENY"
}

# ---------------------------------------------------------------------------
# Enforce it org-wide, but only on resources whose project carries the tag.
# A conditional policy needs one unconditional rule as the default (off).
# ---------------------------------------------------------------------------
resource "google_org_policy_policy" "no_vms_in_host_projects" {
  count = var.host_project_no_vms ? 1 : 0

  name   = "${local.org_parent}/policies/${google_org_policy_custom_constraint.deny_compute_instances[0].name}"
  parent = local.org_parent

  spec {
    rules {
      condition {
        title      = "Shared VPC host projects"
        expression = "resource.matchTagId('${google_tags_tag_key.host[0].id}', '${google_tags_tag_value.shared_vpc_host[0].id}')"
      }
      enforce = "TRUE"
    }
    rules {
      enforce = "FALSE"
    }
  }
}
