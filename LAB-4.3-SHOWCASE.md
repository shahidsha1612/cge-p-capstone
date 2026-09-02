# Lab 4.3 — The Gate Moves to GitHub: A Self-Documenting CI Pipeline (AWS + Actions)

## What This Is

The Conftest gate from Lab 3.4 ran on one laptop. This lab moves it somewhere nobody can skip: GitHub's own servers, running automatically on every pull request. Opening a PR now triggers a pipeline that authenticates to AWS with a credential that expires when the job ends, plans the Lab 2.3 infrastructure, runs the AWS policy library against that plan, scans for misconfigurations a custom Rego rule wouldn't catch, and uploads the full result as a downloadable evidence file — whether the run passes or fails.

## How It Works

```
PR opened ──▶ GitHub Actions runner
                 ├── Assume an AWS IAM role via OIDC (no stored keys, no long-lived secret)
                 ├── terraform plan (nothing applied, just simulated)
                 ├── Conftest gate — SC-28 / AC-3 / CM-6 (Lab 3.4's AWS policies)
                 ├── tfsec scan — catches misconfigurations outside the custom policy set
                 └── Upload evidence artifact: plan.json, plan.txt, conftest-results.json, tfsec.sarif
```

No AWS access key ever touches a GitHub secret. AWS and GitHub trust each other through OIDC: GitHub hands AWS a short-lived signed token proving "this run came from this exact repository," AWS hands back credentials that die when the job ends.

## Three Real Problems, Fixed in Order

Every lab writeup shows the finished YAML. This one is honest about what didn't work on the first try, because the fixes are the actual engineering content.

**1. The trust condition didn't match — GitHub's OIDC subject format has changed.**
The standard tutorial trust policy expects a `sub` claim like `repo:OWNER/REPO:pull_request`. Decoding the actual token GitHub issued showed:
```
"sub": "repo:shahidsha1612@56425439/cge-p-capstone@1332168384:pull_request"
```
GitHub now embeds immutable numeric owner/repo IDs into the subject. The fix keeps the same security intent — pin trust to this one repository, never `repo:*:*` — while wildcarding the IDs:
```hcl
StringLike = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}@*/${var.github_repo}@*:*" }
```

**2. tfsec found a real, expected finding.**
`aws-s3-encryption-customer-key` (HIGH) fired because Lab 2.3's bucket intentionally uses AES256/SSE-S3, not a customer-managed KMS key — a deliberate simplification the lab notes are saving for later. Silencing it required a decision, not a shortcut: it's suppressed in a checked-in `.tfsec/config.yml` with a comment stating exactly why, and SC-28 stays enforced by the Conftest gate regardless (which only requires *an* encryption config, not KMS specifically).

**3. `.gitignore` was silently eating the evidence it was supposed to keep.**
A blanket `plan.json` ignore rule — written to keep Terraform's own working-directory scratch file out of git — also matched `evidence/lab-4-3/plan.json`, the copy this lab explicitly wants committed as an audit artifact. Fixed with a narrow negation: `!evidence/**/plan.json`. A gitignore rule written for one purpose silently breaking a different, later requirement is exactly the kind of gap a real audit review exists to catch.

## Proof the Gate Actually Blocks Something

Two pull requests, same repository, same workflow:

| PR | What it did | Result |
|---|---|---|
| [#1 — Add GRC evidence pipeline](https://github.com/shahidsha1612/cge-p-capstone/pull/1) | Introduced the OIDC trust + `grc-gate.yml` against the compliant Lab 2.3 code | ✅ Passed, merged |
| [#2 — demo: SC-28 policy violation](https://github.com/shahidsha1612/cge-p-capstone/pull/2) | Deliberately deleted the `aws_s3_bucket_server_side_encryption_configuration` on the primary bucket | ❌ [Run 33677472616](https://github.com/shahidsha1612/cge-p-capstone/actions/runs/33677472616) failed — then a fix commit restored it and [Run 33677608734](https://github.com/shahidsha1612/cge-p-capstone/actions/runs/33677608734) passed, and the PR merged |

The failing run's Conftest output, captured as evidence:
```json
{
  "msg": "[SC-28] aws_s3_bucket.primary: aws_s3_bucket has no matching
           aws_s3_bucket_server_side_encryption_configuration.
           Remediation: add one referencing this bucket.",
  "metadata": { "query": "data.compliance.sc28_aws.deny" }
}
```
tfsec independently flagged the same gap under its own check ID (`aws-s3-encryption`) — two unrelated scanners agreeing on the same violation is stronger evidence than either alone.

## What's Actually in the Repo Now

```
.github/workflows/grc-gate.yml         the pipeline itself
.tfsec/config.yml                      one justified suppression, not a blanket exclude
terraform/primitives/oidc-trust/       the OIDC provider + IAM role (applied, not just planned)
evidence/lab-4-3/
  ├── plan.json / plan.txt             what Terraform intended to build
  ├── conftest-results.json            the policy gate's verdict
  ├── tfsec.sarif                      the scanner's verdict
  └── red-green-demo/                  the failing run's results, kept as a permanent record
```

## Why It Matters

Lab 3.4's gate only worked if someone remembered to run it. This one runs itself, on infrastructure nobody can opt out of, and produces its own paper trail in the process:

| What's in the workflow | NIST control |
|---|---|
| `on: pull_request` gating every change | CM-3 (configuration change control) |
| Conftest enforcing SC-28/AC-3/CM-6 in that same run | CM-6 (configuration settings) |
| The workflow running on every PR, automatically | CA-2, CA-7 (assessment, continuous monitoring) |
| tfsec scanning every change | RA-5 (vulnerability scanning) |
| Retained run history + evidence artifacts | AU-9 (protection of audit information) |

An auditor doesn't get a screenshot from me later. They get a link to a run, and the run's own output is the proof.

## Stack

`Terraform` · `AWS S3 + IAM OIDC` · `GitHub Actions` · `Conftest` · `tfsec` · `NIST 800-53`

---

### Suggested post caption

> Moved my compliance gate off my laptop and onto GitHub's servers today — where nobody can skip it. Wired up OIDC so GitHub Actions authenticates to AWS with a credential that expires the moment the job ends (no stored keys, ever), then built a pipeline that plans Terraform, runs my Conftest policy library, scans with tfsec, and uploads the full result as evidence on every single pull request. Along the way: discovered GitHub quietly changed its OIDC subject-claim format (broke the textbook trust policy), caught a legitimate tfsec finding that needed a documented exception instead of a blanket suppression, and found a `.gitignore` rule silently eating the exact evidence file I needed to keep. Then proved the whole thing works with two PRs — one that got blocked for a real policy violation, one that passed after the fix. That's what "the pipeline is the audit trail" actually looks like.
>
> #GRC #DevSecOps #NIST80053 #AWS #GitHubActions #Terraform #OIDC #PolicyAsCode

### Visual idea

A GitHub PR timeline mockup: first commit marked with a red ❌ "grc-gate — Conftest: SC-28 violation," second commit marked with a green ✓ "grc-gate — all checks passed," PR merged. Below it, a small OIDC diagram: GitHub logo → short-lived token → AWS logo, labeled "no keys stored, ever."
