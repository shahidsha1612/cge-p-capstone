# Lab 3.4 — Policy as Code Goes Cross-Cloud: Conftest as a CI Gate

## What This Is

The Lab 3.3 policy library gets its first real test: run it against a *different* cloud. The three NIST 800-53 policies were written for GCP resource types. Pointed at an AWS Terraform plan, they pass — but only because they never actually looked at anything. This lab exposes that failure mode, fixes it with AWS-specific policy variants under the same control IDs, and wires the result into a single script, `policy-gate.sh`, that a CI pipeline can call to block a pull request automatically.

## The Cross-Cloud Lesson

A control ID is portable. The Rego rule that enforces it is not.

```
$ conftest test --policy policies --namespace compliance.sc28 terraform/primitives/compliant-s3/plan.json
2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions
```

That's a GCP-shaped rule (`resource.type == "google_storage_bucket"`) evaluated against an AWS S3 plan. It "passes" because there is nothing in the plan for it to check — a green result that means nothing. This is a real risk in multi-cloud compliance programs: a policy library that silently stops enforcing the moment infrastructure moves cloud.

## The Fix: AWS Variants, Same Control IDs

| Control | GCP rule checks | AWS rule checks |
|---|---|---|
| **SC-28** (Encryption at Rest) | `google_storage_bucket` has a CMEK block | `aws_s3_bucket` has a matching `aws_s3_bucket_server_side_encryption_configuration` |
| **AC-3** (Access Enforcement) | Bucket/firewall lockdown flags | `aws_s3_bucket` has a `aws_s3_bucket_public_access_block` with all four flags `true` |
| **CM-6** (Configuration Settings) | Required `labels` present | Required `tags`/`tags_all` present |

Same three control IDs as Lab 3.3. Different resource types entirely, because AWS represents encryption and public-access enforcement as separate resources wired to the bucket, not inline blocks — and at plan time, S3 bucket names are "known after apply," so the rules match by Terraform *reference* (`aws_s3_bucket.primary.id`) rather than by value.

**Real coverage on the AWS plan:**
```
=== compliance.sc28_aws === 1 test, 1 passed
=== compliance.ac3_aws  === 1 test, 1 passed
=== compliance.cm6_aws  === 1 test, 1 passed
```

## Proof the Gate Fires

Deleting the encryption resource from a throwaway copy of the Lab 2.3 S3 code and re-running the gate:

```
FAIL - compliance.sc28_aws - [SC-28] aws_s3_bucket.primary: aws_s3_bucket has no matching
aws_s3_bucket_server_side_encryption_configuration. Remediation: add one referencing this bucket.

policy-gate: FAIL
```

Exit code 1. Named resource, named control, named fix — a developer can act on that message without anyone explaining what SC-28 means.

## The Gate Script

`scripts/policy-gate.sh` is the one thing a CI pipeline needs to call:

1. Turns a saved `tfplan` into `plan.json`.
2. Runs only the AWS namespaces — including a GCP namespace here would reproduce the exact empty-pass problem this lab just fixed.
3. Captures every namespace's result as machine-readable JSON evidence, even after a failure, so one violation doesn't hide the rest.
4. Exits non-zero the moment any namespace has a violation — Conftest's own exit code is the gate, no extra JSON parsing required.

```bash
bash scripts/policy-gate.sh --workspace terraform/primitives/compliant-s3
```

## Why It Matters

This is the difference between a policy library that *exists* and one that actually *protects* something. Compliance programs that expand into a second cloud provider often assume existing controls carry over automatically — they don't, unless someone checks. This lab makes that check explicit, then turns the fix into an automated gate: the exact script a GitHub Actions workflow will call on every pull request, failing the build closed on any control violation before a human ever has to review it.

## Stack

`Terraform` · `AWS S3` · `Open Policy Agent (OPA)` · `Conftest` · `Rego` · `NIST 800-53`

---

### Suggested post caption

> Watched my own compliance policies quietly fail today — in the "worse than an error" way. Rego rules written for GCP passed against an AWS plan with zero real coverage, because they never matched anything to check. Fixed it by writing AWS-specific variants under the same control IDs (SC-28, AC-3, CM-6), then wrapped the whole thing in a Conftest-based gate script that exits non-zero on any violation. That script is what a CI pipeline will run on every pull request — the exact moment "policy as code" becomes "automatic enforcement."
>
> #GRC #PolicyAsCode #NIST80053 #CloudSecurity #AWS #Terraform #Conftest #OPA

### Visual idea

Two side-by-side terminal panels: left labeled "GCP rule → AWS plan" showing a hollow green "2 passed" with a "0 real checks" caption underneath in red; right labeled "AWS rule → AWS plan" showing a solid green "1 passed" with "real coverage" underneath. Below both, a single red "FAIL" terminal block showing the SC-28 violation message, captioned "the gate that actually catches it."
