# compliant-gcs-bucket

Reusable module: one KMS-backed, versioned, publicly-blocked GCS bucket with a locked-down
compliance floor. Consumers set `environment`, `retention_days`, and naming — everything
security-relevant is hardcoded in `main.tf` and cannot be overridden from the calling module.

## Controls enforced

| Control | Where | How |
|---|---|---|
| SC-12 (Cryptographic Key Establishment/Management) | `google_kms_key_ring.ring`, `google_kms_crypto_key.key` | Module owns and provisions the KMS keyring/key rather than relying on a Google-managed default; the bucket is bound to this customer-managed key only. |
| SC-13 (Cryptographic Protection) | `google_kms_crypto_key.key.rotation_period` | 90-day (`7776000s`) automatic key rotation, fixed in the module — not exposed as a variable. |
| SC-28 (Protection of Information at Rest) | `google_storage_bucket.bucket.encryption.default_kms_key_name` | Every object is encrypted at rest with the CMEK above instead of a Google-managed key. |
| AU-11 (Audit Record Retention) | `google_storage_bucket.bucket.retention_policy`, `versioning` | Object versioning plus a retention policy floor (`retention_days`, validated >= 365 for `prod`) so records can't be deleted or overwritten before the retention window elapses. |
| CM-6 (Configuration Settings) | `local.required_labels` / `local.effective_labels` | `project`, `environment`, `managed_by`, `compliance_scope` labels are merged on top of anything a consumer supplies — a consumer can add labels but cannot remove or override the required ones. |
| AC-3 (Access Enforcement) | `uniform_bucket_level_access`, `public_access_prevention = "enforced"` | Uniform IAM-only access control and an enforced public-access block; no ACL-based or public grants are possible. |

## Interface

**Inputs** (`variables.tf`): `gcp_project`, `location`, `kms_location`, `project_label`,
`environment` (`dev`/`staging`/`prod`), `retention_days` (validated, and validated `>= 365` when
`environment == "prod"`), `bucket_name_suffix`, `labels`.

**Outputs** (`outputs.tf`): `bucket_url`, `bucket_self_link`, `kms_key_id`, and
`compliance_attestation` — a computed map of the controls above, read back as evidence by
downstream policy/OSCAL tooling.

## Usage

```hcl
module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "your-gcp-project"
  project_label      = "cgep-lab"
  environment        = "dev"
  retention_days     = 30
  bucket_name_suffix = "dev-data-001"
}
```

See `terraform/primitives/compliant-gcs/` for a full working consumer.
