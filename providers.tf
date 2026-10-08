provider "google" {
  # The Org Policy API requires a quota/billing project for every call.
  user_project_override = true
  billing_project       = var.billing_project

  # Run as a dedicated org-policy service account (recommended).
  # Leave null to use your own Application Default Credentials.
  impersonate_service_account = var.terraform_service_account
}
