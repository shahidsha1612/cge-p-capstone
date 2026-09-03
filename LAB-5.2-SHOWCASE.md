# Lab 5.2 — Continuous Monitoring: When the Account Reports on Itself

## What This Is

Every lab before this one proved compliance with a snapshot — a signed plan, a signed PR, a signed evidence bundle. This lab turns on the AWS-native services that keep producing evidence without anyone pushing a commit: CloudTrail records every API call made in the account, AWS Config tracks what every resource looks like over time, and Security Hub normalizes findings from both into a list already mapped to NIST 800-53 control IDs. No vendor console, no dashboard to babysit — just JSON an assessor can pull directly.

## Control Mapping

| Service | NIST 800-53 | What it proves |
|---|---|---|
| CloudTrail | AU-2, AU-12, AU-10 | Every management-plane call, multi-region, with a tamper-evident hourly digest signed by an AWS-managed key |
| AWS Config | CM-2, CM-6, CM-8 | Continuous inventory of what every resource actually looks like |
| Security Hub | RA-5, SI-4 | Findings from Config + native checks, normalized to control IDs |

## Proof, End to End

```
$ aws cloudtrail get-trail-status --name cgep-lab-mgmt --region us-east-1
{ "IsLogging": true, "LatestDeliveryTime": "2026-09-03T22:36:14+01:00" }

$ aws securityhub describe-hub --region us-east-1
"arn:aws:securityhub:us-east-1:467138365754:hub/default"
```

15 real findings captured to `evidence/lab-5-2/security-hub-findings.json` — CloudWatch alarm-coverage gaps (missing metric filters for CloudTrail config changes, S3 bucket policy changes, NACL changes), exactly what a freshly-deployed account with no alarms wired up should surface.

## The Honest Correction

The lab doc treats AWS Config as optional: skip it for cost, and Security Hub will still hand you one useful fallback — a CRITICAL "AWS Config should be enabled" finding. I tested that claim instead of taking it on faith, and it doesn't hold. Without Config, `aws securityhub get-enabled-standards` showed all three subscribed standards (NIST 800-53, FSBP, CIS) stuck in:

```json
"StandardsStatus": "INCOMPLETE",
"StandardsStatusReason": { "StatusReasonCode": "NO_AVAILABLE_CONFIGURATION_RECORDER" }
```

Zero findings — not even the fallback one — after 40+ minutes of polling. Security Hub's standards evaluation is now fully gated on Config being present, not gracefully degraded without it. I added Config (`config.tf` — recorder, delivery channel, service-linked role) to unblock it; 15 findings appeared within ten minutes of the recorder starting.

The practical implication is sharper than the doc suggests: in an org-managed account where Config is blocked by SCP, you don't get a self-documenting gap finding — you get silence. The real evidence of that gap has to be pulled from `get-enabled-standards`, not `get-findings`. That distinction is now documented in `terraform/baselines/aws/README.md`.

## Also Surfaced: a Real Account-Level Gotcha

Getting to that point required discovering that AWS accounts on the newer "Free Plan" credit tier block Security Hub and GuardDuty outright (`SubscriptionRequiredException`) regardless of IAM permissions — confirmed by testing S3/EC2/IAM (all fine) against Security Hub/GuardDuty (both blocked identically) on the same admin credentials. Fixed by upgrading the account off the Free Plan tier, which required root login since IAM users are blocked from billing actions by default. Not part of the lab doc, but exactly the kind of environment friction a real deployment runs into.

## Why It Matters

An assessor doesn't need to trust that I ran the right checks — they read `get-findings` and `get-enabled-standards` directly, both already speaking NIST control language. And when I found the lab doc's own claim didn't survive contact with a real account, I tested it, documented the actual behavior, and adjusted the deployment instead of just going along with the doc. That's the difference between following a compliance checklist and actually verifying the control works the way it's claimed to.

## Stack

`AWS CloudTrail` · `AWS Config` · `AWS Security Hub` · `Terraform` · `NIST 800-53`

---

### Suggested post caption

> Stood up AWS's native continuous-monitoring stack today — CloudTrail, Config, and Security Hub, all mapped to NIST 800-53 controls out of the box. The lab doc claimed Config was optional and Security Hub would still hand you a useful fallback finding if you skipped it. I tested that instead of assuming it — and on a real account, skipping Config means Security Hub evaluates *nothing at all*, not even the fallback. Documented the real behavior, added Config, captured real findings, then tore everything down same-day. Small thing, but it's the difference between reading a compliance doc and verifying the control.
>
> #GRC #NIST80053 #AWS #ContinuousMonitoring #SecurityHub #DevSecOps

### Visual idea

Three stacked panels — CloudTrail, Config, Security Hub — each with its control IDs and a one-line "proves" caption, connected by arrows into a single Security Hub findings panel. Below it, a small red-flagged callout box: "Doc said: fallback finding without Config. Reality: zero findings without Config." with the `NO_AVAILABLE_CONFIGURATION_RECORDER` status code shown in monospace.
