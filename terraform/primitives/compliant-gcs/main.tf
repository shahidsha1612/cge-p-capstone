terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = "grc-cap-p"
  region  = "us-central1"
}

module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "grc-cap-p"
  project_label      = "cgep-lab"
  environment        = "dev"
  retention_days     = 30
  bucket_name_suffix = "adl-cap-001"
}

output "attestation"      { value = module.data_bucket.compliance_attestation }
output "bucket_url"       { value = module.data_bucket.bucket_url }
output "bucket_self_link" { value = module.data_bucket.bucket_self_link }
output "kms_key_id"       { value = module.data_bucket.kms_key_id }
