terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
  }

  # Partial backend configuration — supply bucket/prefix at init time:
  #   terraform init -backend-config=backend.hcl
  backend "gcs" {}
}
