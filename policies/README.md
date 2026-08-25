# Compliance Policies

Rego policies, enforced by OPA, that check a Terraform plan (`terraform show -json`) against NIST 800-53 controls before infrastructure is ever applied. An empty `deny` set means compliant.

| Policy file | Control | Severity | What it checks | Remediation |
|---|---|---|---|---|
| `sc28_encryption.rego` | SC-28 (Encryption at Rest) | High | Every `google_storage_bucket` has a customer-managed encryption key (CMEK) block. | Add `encryption { default_kms_key_name = ... }` referencing a `google_kms_crypto_key` you control. |
| `ac3_no_public.rego` | AC-3 (Access Enforcement) | Critical | Buckets enforce `uniform_bucket_level_access` + `public_access_prevention=enforced`; firewalls don't allow `0.0.0.0/0` on management ports (22, 3389). | Lock down bucket access settings. For firewalls, narrow `source_ranges` or remove the rule. |
| `cm6_required_tags.rego` | CM-6 (Configuration Settings) | Medium | Taggable resources (`google_storage_bucket`, `google_compute_instance`, `google_compute_disk`) carry all four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. | Add the missing labels to the resource. |

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
