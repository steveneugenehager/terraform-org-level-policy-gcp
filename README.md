# terraform-org-level-policy-gcp

Organization-wide security baseline for the GCP organization, managed as
[Organization Policies](https://cloud.google.com/resource-manager/docs/organization-policy/overview)
with the `google_org_policy_policy` resource (Org Policy API v2).

This repo manages **org-level** constraints only. Environment-specific
exceptions (for example, allowing external IPs in `lab`) belong with the
folders they apply to, in `terraform-folder-setup-gcp` or downstream repos.

## Where this fits

| Order | Repo / stage | Purpose |
|---|---|---|
| 1 | bootstrap repo | Org identity, admin SAs, bootstrap project, state bucket, **org-policy SA** |
| 2 | **terraform-org-level-policy-gcp** (this repo) | Org-wide constraints |
| 3 | terraform-folder-setup-gcp | Environment folders (+ folder-level policy overrides) |
| 4 | project / workload repos | Projects and resources |

Apply this repo **before** creating environment projects. Several constraints,
including `compute.skipDefaultNetworkCreation`, only affect resources created
after the policy takes effect.

## Policies

| Constraint | Type | Effect |
|---|---|---|
| `compute.skipDefaultNetworkCreation` | boolean | New projects don't get the `default` VPC |
| `compute.requireOsLogin` | boolean | SSH access goes through IAM (OS Login), not metadata keys |
| `compute.vmExternalIpAccess` | list (deny all) | No VM may have an external IP |
| `iam.allowedPolicyMemberDomains` | list | IAM grants only to identities in your customer ID(s); blocks `allUsers`/`allAuthenticatedUsers` |
| `iam.disableServiceAccountKeyCreation` | boolean | No downloadable service account keys |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | boolean | Default compute/App Engine SAs don't receive Editor |
| `storage.uniformBucketLevelAccess` | boolean | Buckets must use uniform (IAM-only) access |
| `storage.publicAccessPrevention` | boolean | Buckets/objects can't be made public |
| `sql.restrictPublicIp` | boolean | Cloud SQL instances can't have public IPs |
| `gcp.resourceLocations` | list | Regional/zonal resources only in allowed locations (default `in:us-locations`) |

Each list constraint can be switched off by variable (empty list / `false`).
Boolean constraints are controlled by `enforced_boolean_constraints`.

## Prerequisites

1. **Org-policy service account** (create it in the bootstrap repo):
   - `roles/orgpolicy.policyAdmin` on the **organization**
   - `roles/serviceusage.serviceUsageConsumer` on the billing/quota project
   - `roles/storage.objectAdmin` on the state bucket
2. **`orgpolicy.googleapis.com` enabled** on the billing/quota project. The
   bootstrap repo (`terraform-bootstrap-project-gcp`) enables it; this repo
   does not.
3. **Your user** needs `roles/iam.serviceAccountTokenCreator` on that SA to
   impersonate it.
4. **A GCS bucket** for Terraform state.
5. **Your Workspace customer ID**:
   ```bash
   gcloud organizations describe ORG_ID \
     --format='value(owner.directoryCustomerId)'
   ```

Organization Admin alone does **not** include `orgpolicy.policyAdmin`.

## Usage

```bash
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
# edit both

gcloud auth application-default login

terraform init -backend-config=backend.hcl
terraform plan -out=org-policy.tfplan
terraform apply org-policy.tfplan
```

## Policies that already exist

Organizations created since early 2024 may already have some of these enforced
under Google's secure-by-default rollout. Creating a policy that already exists
fails with a 409, so check first:

```bash
gcloud org-policies list --organization=ORG_ID
```

Import any that exist before the first apply:

```bash
terraform import \
  'google_org_policy_policy.boolean["iam.disableServiceAccountKeyCreation"]' \
  organizations/ORG_ID/policies/iam.disableServiceAccountKeyCreation

terraform import \
  'google_org_policy_policy.allowed_policy_member_domains[0]' \
  organizations/ORG_ID/policies/iam.allowedPolicyMemberDomains
```

The other list-constraint addresses are
`google_org_policy_policy.vm_external_ip_access[0]` and
`google_org_policy_policy.resource_locations[0]`.

### Managed constraints

Newer organizations may also show **managed** versions of some of these
constraints in that list, named with `.managed.` (for example,
`iam.managed.disableServiceAccountKeyCreation`). Managed and classic
constraints are separate policies, so they don't conflict and neither one
needs importing for the other. If a managed version is already enforced, the
classic one in this repo is redundant for that control. Keep it for
consistency, or drop it from `enforced_boolean_constraints`.

## Rollout cautions

- **`iam.disableServiceAccountKeyCreation`**: confirm nothing depends on SA
  keys. For Workspace Admin SDK automation, have the SA hold the Workspace
  admin roles directly and use impersonation or attached credentials instead
  of a key file. Existing keys keep working. Only new key creation is blocked.
- **`iam.allowedPolicyMemberDomains`**: blocks granting roles to any outside
  account, including personal Gmail addresses and public (`allUsers`) access.
  Some Google-managed features need exceptions; add a project-level override
  when you hit one.
- **`compute.vmExternalIpAccess`** and **`compute.requireOsLogin`**: relax
  these per folder (e.g., `lab`) if you need public VMs or metadata SSH keys.
- **`gcp.resourceLocations`**: some services create resources in `global`,
  which is unaffected. Multi-region products may need `in:us-locations`
  rather than a single region.
- Policies propagate within a few minutes but can take longer.
- Policies don't retroactively change existing resources. Clean up existing
  `default` networks, public buckets, etc. separately.

## Folder-level overrides (example)

Put these in the folder-setup repo, next to the folders they relax:

```hcl
resource "google_org_policy_policy" "lab_allow_external_ip" {
  name   = "${google_folder.lab.name}/policies/compute.vmExternalIpAccess"
  parent = google_folder.lab.name

  spec {
    rules {
      allow_all = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "lab_no_os_login" {
  name   = "${google_folder.lab.name}/policies/compute.requireOsLogin"
  parent = google_folder.lab.name

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}
```

`google_folder.<x>.name` already has the `folders/123...` format.

## Verifying

```bash
# Effective policy for a constraint at the org
gcloud org-policies describe compute.skipDefaultNetworkCreation \
  --organization=ORG_ID --effective

# Effective policy as a specific project sees it (includes inheritance)
gcloud org-policies describe compute.vmExternalIpAccess \
  --project=PROJECT_ID --effective

terraform output managed_policies
```

## Removing a policy

Removing a constraint from `enforced_boolean_constraints` (or setting a list
variable empty / `false`) deletes the policy on the next apply. The org then
falls back to Google's default for that constraint, which may be
**unenforced**.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform/provider versions, GCS backend (partial config) |
| `providers.tf` | Google provider with quota project and SA impersonation |
| `variables.tf` | Inputs with validation |
| `main.tf` | All org policies |
| `outputs.tf` | List of managed policy names |
| `terraform.tfvars.example` | Example inputs |
| `backend.hcl.example` | Example state backend config |
