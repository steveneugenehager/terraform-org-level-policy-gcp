# ==================================================================================================
# File:        versions.tf
# Module:      terraform-org-level-policy-gcp (repo)
# Description: Terraform/provider version pins and partial GCS backend config.
# ==================================================================================================
#
# Change History
# --------------------------------------------------------------------------------------------------
# Date        Author                     Version  Description
# ----------  -------------------------  -------  --------------------------------------------------
# 2026-10-08  Steve Hager                1.0.0    Initial creation.
# YYYY-MM-DD  <name>                     x.y.z    <what changed and why>
# --------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Partial backend configuration — supply bucket/prefix at init time:
  #   terraform init -backend-config=backend.hcl
  backend "gcs" {}
}
