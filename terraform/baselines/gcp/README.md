# Lab 5.4: GCP Security Services Baseline

GCP's counterpart to Lab 5.2's AWS baseline, but preventive rather than
detective: instead of aggregating findings after the fact, GCP leans on
Org Policy (reject at the API), Workload Identity Federation (no
downloadable service-account keys), and Data Access audit logs (once
turned on).

## Deployment

- Project: `grc-cap-p`
- Region: `us-central1`
- Applied as: `shaid@adl-consulting.co.uk` (day-to-day account, used for
  every prior GCP lab) for `wif.tf` and `audit_logs.tf`; `aceisace80@gmail.com`
  (the project's actual `roles/owner`) via a short-lived access token for
  the `org_policy.tf` attempt — see deviation below for why that account
  split exists and why it still wasn't enough.

## Control mapping

| Piece | Resource(s) | NIST 800-53 controls | Status |
|---|---|---|---|
| Workload Identity Federation | `google_iam_workload_identity_pool.github`, `..._provider.github`, `google_service_account.gha`, `google_project_iam_member.gha_viewer`, `google_service_account_iam_binding.wif_user` | AC-2, IA-2 (key-free, short-lived identity for CI) | **Deployed** |
| Data Access audit logs | `google_project_iam_audit_config.storage/kms/iam` | AU-2 (event logging), AU-12 (audit generation) | **Deployed** |
| Org Policy (uniform bucket access, disable SA keys, require OS Login) | `google_org_policy_policy.*` | CM-6 (config settings), AC-2 (account management), AC-3 (access enforcement) | **Not deployable** — see deviation |

## Deviation from the lab doc: Org Policy requires an Organization, full stop

The lab doc's prerequisites say "a project owner can grant these at project
scope" and treats `roles/orgpolicy.policyAdmin` as sufficient. On this
project that assumption breaks down completely, and not because of a
missing IAM role.

`grc-cap-p` is a standalone project — `gcloud projects describe grc-cap-p`
returns no `parent` field, meaning it has no ancestor Organization (typical
for a project created under a personal Gmail account rather than a Google
Workspace/Cloud Identity domain). Every attempt to write an Org Policy
failed with `orgpolicy.policies.create` / `setOrgPolicy` permission denied
— including under the account holding `roles/owner`, the project's actual
owner, on both the v2 API (`google_org_policy_policy`) and the legacy v1
API (`gcloud resource-manager org-policies enable-enforce`). Full error
transcript in `evidence/lab-5-4/org-policy-error.txt`.

**This is a hard structural limit, not a permissions gap that could be
fixed by granting a different role.** Organization Policy Service anchors
its policy hierarchy at an Organization resource; without one, there is
nowhere for a project-scoped override to attach, regardless of who's
asking. This is the GCP equivalent of Lab 5.2's AWS Free Plan gate
(`SubscriptionRequiredException` on Security Hub/GuardDuty) — an
account-tier restriction that no amount of IAM tuning resolves.

The consequence was demonstrated live rather than assumed: with Org Policy
unenforceable, a JSON key was successfully created for the WIF service
account (`cgep-grc-gate-sa@grc-cap-p.iam.gserviceaccount.com`) — the exact
action `iam.disableServiceAccountKeyCreation` is supposed to reject. No
`FAILED_PRECONDITION` was raised. The key was deleted immediately after
capturing the result, so nothing was left live.

`org_policy.tf` is kept in this repo as the correct IaC for an
org-enabled environment (a capstone or client engagement running under a
real Google Workspace org would need exactly these three resources) — it's
just not something this particular project can prove out.

## Why identity-first still holds, even with the gap

WIF and Data Access logs deployed cleanly and don't depend on an
Organization resource at all — they're IAM and audit-config primitives
scoped entirely to the project. The lesson holds even with one-third of
the baseline blocked: prevention (Org Policy) needs a policy hierarchy to
attach to, but identity controls (WIF) and detection (audit logs) work on
any project, organization or not.

## Evidence captured

- `evidence/lab-5-4/iam-policy.json` — `auditConfigs` block from
  `gcloud projects get-iam-policy`, confirming `DATA_READ`/`DATA_WRITE`/
  `ADMIN_READ` enabled for `storage`, `iam`, and `cloudkms`.
- `evidence/lab-5-4/wif-pools.json` — the live `github-actions` pool,
  `state: ACTIVE`.
- `evidence/lab-5-4/org-policy-error.txt` — full transcript of the Org
  Policy failure (both API versions) plus the key-creation proof.

## Cleanup

WIF pools soft-delete for 30 days once destroyed — a `terraform destroy`
here means `github-actions` can't be recreated with the same ID until that
window lapses (or `--purge` after `undelete`). Not destroyed as of this
write-up; ask before tearing down if the WIF identity is still needed for
a demo workflow.
