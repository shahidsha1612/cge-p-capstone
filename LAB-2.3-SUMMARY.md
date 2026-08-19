# Lab 2.3 Summary — Compliant S3 Primitive

## What this lab was about

Build a Terraform module for a single AWS S3 bucket that satisfies five NIST 800-53 controls, and prove it with machine-readable evidence (JSON) instead of screenshots:

- **SC-28** — Protection of information at rest (encryption)
- **AU-3** — Content of audit records (access logging)
- **AU-6** — Audit review, analysis, and reporting
- **CM-6** — Configuration settings (tagging baseline)
- **AC-3** — Access enforcement (public access block)

## Environment setup

- Machine had neither Terraform nor AWS CLI installed. Installed both via `winget`:
  - Terraform v1.15.8
  - AWS CLI 2.36.21
- Created an IAM user (`terraform-lab`) with a long-term access key in a sandbox AWS account (account ID redacted; not needed by any downstream lab step).
- Configured a local AWS CLI profile named `sandbox` (`aws configure --profile sandbox`, region `us-east-1`).
- Verified auth with `aws sts get-caller-identity`.

## What was built

Module at `terraform/primitives/compliant-s3/`:

- `main.tf` — AWS provider with `default_tags` (Project / Environment / ManagedBy / ComplianceScope), a `random_id` bucket-suffix generator, the primary data bucket, its server-side encryption (AES-256), versioning, public access block, and a companion log bucket (with ownership controls, ACL, encryption, public access block) wired up via `aws_s3_bucket_logging`.
- `variables.tf` — `project_name`, `environment`, `bucket_suffix`, each with validation rules.
- `outputs.tf` — bucket ARN/name, log bucket ARN, and an `encryption_algorithm` output as a direct SC-28 attestation.
- `README.md` — one-paragraph statement of which controls the module enforces.

11 resources created on `terraform apply`:

```
bucket_arn            = arn:aws:s3:::cgep-lab-dev-data-ebefbc2c
bucket_name           = cgep-lab-dev-data-ebefbc2c
encryption_algorithm  = AES256
log_bucket_arn        = arn:aws:s3:::cgep-lab-dev-logs-ebefbc2c
```

## Verification performed

Ran the three AWS CLI checks against the live bucket and confirmed compliance:

- `aws s3api get-bucket-encryption` → AES256 confirmed
- `aws s3api get-bucket-versioning` → Enabled
- `aws s3api get-public-access-block` → all four flags `true` (BlockPublicAcls, IgnorePublicAcls, BlockPublicPolicy, RestrictPublicBuckets)

## Evidence captured

- `evidence/lab-2-3/plan.json` — from `terraform show -json tfplan`
- `evidence/lab-2-3/state.json` — from `terraform show -json`

Both scanned for sensitive data before publishing: no AWS account ID, no access keys, no IAM ARNs, no emails found. (S3 bucket ARNs don't embed the account ID, unlike IAM ARNs, so there was nothing to redact.)

## Git / GitHub

- Initialized a git repo at the capstone root (`E:\Freelance\GRC`) — after correcting an initial `git init` that had been run one level too deep, inside the module folder itself.
- Committed exactly the six checklist files plus `.gitignore` (which excludes `.terraform/`, `*.tfstate*`, `tfplan`, `crash.log`).
- Created a **public** GitHub repo via `gh repo create` and pushed: **https://github.com/shahidsha1612/cge-p-capstone**

## Still open

- **Cleanup decision**: the sandbox bucket is still live. Lab cost guidance assumes same-day `terraform destroy` (cost stays under $0.01). Not yet run — pending your call on whether a later lab builds on this bucket.
- A stray empty directory (`terraform/primitives/compliant-s3/terraform/primitives/`) is sitting around locally from an earlier `mkdir` typo — untracked, harmless, safe to delete whenever.

## How this feeds the capstone (per the lab)

- Ch 3: Rego policies will read this exact `plan.json` to prove each control programmatically.
- Ch 4: the manual `plan → apply → show -json` ritual becomes a CI step; these evidence files are the seed of signed evidence bundles.
- Ch 6: an OSCAL Component Definition will point SC-28's `implemented-requirement` at `evidence/lab-2-3/state.json` as the audit trail.
