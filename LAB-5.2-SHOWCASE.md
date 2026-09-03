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

15 findings captured to `evidence/lab-5-2/security-hub-findings.json` — CloudWatch alarm-coverage gaps (missing metric filters for CloudTrail config changes, S3 bucket policy changes, NACL changes), the expected findings for a freshly-deployed account with no CloudWatch alarms configured yet.

## Deploying Config

Alongside CloudTrail and Security Hub, this deployment also enabled AWS Config (`config.tf` — recorder, delivery channel, service-linked role) so Security Hub's NIST 800-53 and FSBP standards could evaluate against a live resource inventory. Full control mapping for Config (CM-2, CM-6, CM-8) is in `terraform/baselines/aws/README.md`, along with the account's `get-enabled-standards` output before and after the recorder came online.

## Why It Matters

An assessor doesn't need to trust that the right checks ran — they read `get-findings` directly, already speaking NIST control language. CloudTrail, Config, and Security Hub together turn "we are compliant" from a claim into a live, queryable feed.

## Stack

`AWS CloudTrail` · `AWS Config` · `AWS Security Hub` · `Terraform` · `NIST 800-53`

---

### Suggested post caption

> Stood up AWS's native continuous-monitoring stack today — CloudTrail, Config, and Security Hub, all mapped to NIST 800-53 controls out of the box. Captured real findings, then tore everything down same-day to keep costs at zero. Continuous monitoring, the way an auditor actually wants to see it: a live JSON feed, not a slide deck.
>
> #GRC #NIST80053 #AWS #ContinuousMonitoring #SecurityHub #DevSecOps

### Visual idea

Three stacked panels — CloudTrail, Config, Security Hub — each with its control IDs and a one-line "proves" caption, connected by arrows into a single Security Hub findings panel showing a sample finding.
