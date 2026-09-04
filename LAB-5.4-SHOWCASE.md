# Lab 5.4 — GCP's Identity-First Bet, and Where It Needs an Organization to Cash Out

## What This Is

Lab 5.2 gave AWS a detective control: Security Hub flags a bad resource after it exists. This lab is GCP's preventive answer — Org Policy rejects the bad API call before it happens, Workload Identity Federation replaces downloadable service-account keys with short-lived OIDC-minted tokens, and Data Access logs record every read/write once turned on. Same OIDC pattern as the AWS trust in Lab 4.3, different cloud.

## Control Mapping

| Piece | NIST 800-53 | Status |
|---|---|---|
| Workload Identity Federation | AC-2, IA-2 | Deployed |
| Data Access audit logs | AU-2, AU-12 | Deployed |
| Org Policy (uniform bucket access, no SA keys, require OS Login) | CM-6, AC-2, AC-3 | Blocked — see below |

## Proof, End to End

```
$ terraform output -json
{
  "wif_service_account_email": "cgep-grc-gate-sa@grc-cap-p.iam.gserviceaccount.com",
  "workload_identity_provider": "projects/661037596836/locations/global/workloadIdentityPools/github-actions/providers/github"
}

$ gcloud iam workload-identity-pools list --location=global --project=grc-cap-p
NAME: projects/661037596836/locations/global/workloadIdentityPools/github-actions
STATE: ACTIVE
```

Data Access logs confirmed enabled for `storage`, `iam`, and `cloudkms` (`DATA_READ`/`DATA_WRITE`/`ADMIN_READ`) in `evidence/lab-5-4/iam-policy.json`.

## The Real Finding: Org Policy Needs an Organization, Not Just a Role

The lab doc says a project owner can grant Org Policy at project scope. On `grc-cap-p` — a standalone project with no parent Organization — that's false. Every attempt failed with `orgpolicy.policies.create` denied, **even under the account holding `roles/owner`**, on both the current and legacy Org Policy APIs. Granting a role doesn't fix it, because there's no organization-level policy hierarchy for a project-scoped override to attach to. It's the GCP mirror of Lab 5.2's AWS Free Plan gate blocking Security Hub — an account-tier wall, not an IAM gap.

Rather than assume that and move on, the gap was proven live: with Org Policy unenforceable, a JSON key was created for the WIF service account — the exact action `iam.disableServiceAccountKeyCreation` exists to reject — with no error. Deleted immediately after capturing the result. Full transcript in `evidence/lab-5-4/org-policy-error.txt`.

## Why It Still Matters

Two-thirds of the baseline (identity federation, audit logging) needed nothing but a project and don't care whether an Organization exists. The one piece that does — preventive policy enforcement — is a reminder that "identity-first" security has a floor: it works at the resource level, but real *prevention* needs a hierarchy to enforce against. `org_policy.tf` stays in the repo as correct IaC for a real org-enabled engagement; it just can't be proven out on this project.

## Stack

`GCP Workload Identity Federation` · `Cloud Audit Logs` · `Org Policy (v1 + v2)` · `Terraform` · `NIST 800-53`

---

### Suggested post caption

> Built GCP's identity-first security baseline today — Workload Identity Federation (no more downloadable service-account keys) and Data Access audit logging, both live. Then hit a real wall: Org Policy, GCP's preventive control layer, structurally requires a Google Cloud Organization — even project ownership doesn't get you around it. Proved the gap live instead of assuming it, the same way a real audit would. Sometimes the best finding is the control that *can't* be turned on, and why.
>
> #GRC #NIST80053 #GCP #WorkloadIdentityFederation #OrgPolicy #DevSecOps

### Visual idea

Two green panels (WIF, Audit Logs) feeding into a live pipeline, and one red/locked panel (Org Policy) with a "requires Organization" stamp — showing the baseline is two-thirds live, one-third structurally blocked, with the diagnostic evidence underneath.
