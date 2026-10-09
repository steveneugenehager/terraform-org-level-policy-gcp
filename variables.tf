# ==================================================================================================
# File:        variables.tf
# Module:      terraform-org-level-policy-gcp (repo)
# Description: Validated inputs for the org, identity, and each policy constraint.
# ==================================================================================================
#
# Change History
# --------------------------------------------------------------------------------------------------
# Date        Author                     Version  Description
# ----------  -------------------------  -------  --------------------------------------------------
# 2026-10-08  Steve Hager                1.0.0    Initial creation.
# YYYY-MM-DD  <name>                     x.y.z    <what changed and why>
# --------------------------------------------------------------------------------------------------
variable "org_id" {
  description = "Numeric GCP organization ID (gcloud organizations list)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be the numeric organization ID, not the domain name."
  }
}

variable "billing_project" {
  description = "Project used for API quota/billing on Org Policy calls (e.g., the bootstrap project). orgpolicy.googleapis.com is enabled here."
  type        = string
}

variable "terraform_service_account" {
  description = "Email of the service account Terraform impersonates. Needs roles/orgpolicy.policyAdmin on the org and roles/serviceusage.serviceUsageConsumer on billing_project. Null = use ADC."
  type        = string
  default     = null
}

variable "enforced_boolean_constraints" {
  description = "Boolean constraints to enforce at the organization level. Remove an entry to stop managing it (the org then falls back to Google's default for that constraint)."
  type        = list(string)
  default = [
    "compute.skipDefaultNetworkCreation",
    "compute.requireOsLogin",
    "iam.disableServiceAccountKeyCreation",
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "storage.uniformBucketLevelAccess",
    "storage.publicAccessPrevention",
    "sql.restrictPublicIp",
  ]

  validation {
    condition = alltrue([
      for c in var.enforced_boolean_constraints : contains([
        "compute.skipDefaultNetworkCreation",
        "compute.requireOsLogin",
        "iam.disableServiceAccountKeyCreation",
        "iam.automaticIamGrantsForDefaultServiceAccounts",
        "storage.uniformBucketLevelAccess",
        "storage.publicAccessPrevention",
        "sql.restrictPublicIp",
      ], c)
    ])
    error_message = "enforced_boolean_constraints contains a constraint this module does not know about. Add it to the validation list deliberately if intended."
  }
}

variable "allowed_customer_ids" {
  description = "Google Workspace / Cloud Identity customer IDs allowed in IAM policies (iam.allowedPolicyMemberDomains). Find yours with: gcloud organizations describe ORG_ID --format='value(owner.directoryCustomerId)'. Empty list = don't manage this constraint."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.allowed_customer_ids : can(regex("^C[0-9a-z]+$", id))])
    error_message = "Customer IDs look like 'C0abc123d' (they start with a capital C)."
  }
}

variable "allowed_locations" {
  description = "Allowed resource locations for gcp.resourceLocations, using value groups or explicit locations (e.g., in:us-locations, in:us-central1-locations). Empty list = don't manage this constraint."
  type        = list(string)
  default     = ["in:us-locations"]
}

variable "deny_vm_external_ips" {
  description = "If true, enforce compute.vmExternalIpAccess with deny-all at the org (no VM may have an external IP). Relax per folder/project in downstream repos."
  type        = bool
  default     = true
}
