# Compliance Policies

Rego policies, enforced by OPA/Conftest, that check a Terraform plan (`terraform show -json`) against NIST 800-53 controls before infrastructure is ever applied. An empty `deny` set means compliant.

A control ID (SC-28, AC-3, CM-6) is portable across clouds; the Rego rule that checks it is not — a rule written for `google_storage_bucket` has nothing to say about an `aws_s3_bucket`, and will "pass" an AWS plan with zero real coverage. This library keeps one file pair per control: a GCP variant and an AWS variant, same control ID, different resource types.

## GCP variants (Lab 3.3)

| Policy file | Control | Severity | What it checks | Remediation |
|---|---|---|---|---|
| `sc28_encryption.rego` | SC-28 (Encryption at Rest) | High | Every `google_storage_bucket` has a customer-managed encryption key (CMEK) block. | Add `encryption { default_kms_key_name = ... }` referencing a `google_kms_crypto_key` you control. |
| `ac3_no_public.rego` | AC-3 (Access Enforcement) | Critical | Buckets enforce `uniform_bucket_level_access` + `public_access_prevention=enforced`; firewalls don't allow `0.0.0.0/0` on management ports (22, 3389). | Lock down bucket access settings. For firewalls, narrow `source_ranges` or remove the rule. |
| `cm6_required_tags.rego` | CM-6 (Configuration Settings) | Medium | Taggable resources (`google_storage_bucket`, `google_compute_instance`, `google_compute_disk`) carry all four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. | Add the missing labels to the resource. |

## AWS variants (Lab 3.4)

| Policy file | Control | Severity | What it checks | Remediation |
|---|---|---|---|---|
| `sc28_encryption_aws.rego` | SC-28 (Encryption at Rest) | High | Every `aws_s3_bucket` has a matching `aws_s3_bucket_server_side_encryption_configuration` (matched by reference, since bucket names are "known after apply" at plan time). | Add `aws_s3_bucket_server_side_encryption_configuration { bucket = aws_s3_bucket.<name>.id ... }`. |
| `ac3_no_public_aws.rego` | AC-3 (Access Enforcement) | Critical | Every `aws_s3_bucket` has a matching `aws_s3_bucket_public_access_block` with all four flags (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) set to `true`. | Add a complete `aws_s3_bucket_public_access_block` referencing the bucket. |
| `cm6_required_tags_aws.rego` | CM-6 (Configuration Settings) | Medium | Taggable resources (`aws_s3_bucket`, `aws_dynamodb_table`, `aws_lambda_function`, `aws_kms_key`, `aws_cloudtrail`) carry all four required tags: `Project`, `Environment`, `ManagedBy`, `ComplianceScope` (checked via `tags_all` when `default_tags` is used, falling back to `tags`). | Add the missing tags or configure provider `default_tags`. |

## Running the tests

```bash
opa test -v policies/
```

## Checking a real plan

```bash
terraform show -json tfplan > plan.json
opa eval -d policies -i plan.json data.compliance.sc28.deny --format=pretty
opa eval -d policies -i plan.json data.compliance.ac3.deny  --format=pretty
opa eval -d policies -i plan.json data.compliance.cm6.deny  --format=pretty
```

## Running the CI gate (AWS)

`scripts/policy-gate.sh` wraps Conftest for CI: it turns a saved `tfplan` into `plan.json`, runs only the AWS namespaces (`compliance.sc28_aws`, `compliance.ac3_aws`, `compliance.cm6_aws`), writes machine-readable results to `evidence/lab-3-4/conftest-results.json`, and exits non-zero on any violation.

```bash
bash scripts/policy-gate.sh --workspace terraform/primitives/compliant-s3
```
