# Lab 5.2: AWS Security Services Baseline

Deploys three account-level AWS-native services that continuously produce
compliance evidence, rather than a one-time snapshot: CloudTrail, AWS Config,
and Security Hub (NIST 800-53 Rev 5 + AWS Foundational Security Best
Practices standards).

## Deployment

- Account: `467138365754` (see note below on why this differs from the
  `sandbox` profile used in earlier labs)
- Region: `us-east-1`
- Profile: `sandbox2`

## Control mapping

| Service | Resource(s) | NIST 800-53 controls | What it evidences |
|---|---|---|---|
| CloudTrail | `aws_cloudtrail.mgmt`, `aws_s3_bucket.trail` | AU-2 (event logging), AU-12 (audit generation), AU-10 (non-repudiation, via `enable_log_file_validation`) | Every management-plane API call in the account is recorded, multi-region, with a tamper-evident hourly digest signed by an AWS-managed key. |
| AWS Config | `aws_config_configuration_recorder.this`, `aws_config_delivery_channel.this` | CM-2 (baseline configuration), CM-6 (configuration settings), CM-8 (component inventory) | Continuous inventory of what every resource in the account looks like, which is what Security Hub's standards checks evaluate against. |
| Security Hub | `aws_securityhub_account.this`, `aws_securityhub_standards_subscription.nist_800_53`, `aws_securityhub_standards_subscription.fsbp` | RA-5 (vulnerability/misconfiguration scanning), SI-4 (system monitoring) | Normalizes findings from Config, native checks, and (if enabled) GuardDuty into one list mapped to control IDs an assessor can read directly. |

## Deviation from the lab doc: Config is not actually optional

The lab doc treats AWS Config as optional — skip it for cost, and Security
Hub will still surface one useful finding ("AWS Config should be enabled").
That is **not what happened in this account.** Before Config was deployed,
`aws securityhub get-enabled-standards` showed all three standards
subscriptions (NIST 800-53, FSBP, CIS) stuck in:

```json
"StandardsStatus": "INCOMPLETE",
"StandardsStatusReason": { "StatusReasonCode": "NO_AVAILABLE_CONFIGURATION_RECORDER" }
```

No findings were produced at all — not even the fallback "Config is
missing" finding the doc promises — after 40+ minutes of polling. Security
Hub's standards-based control evaluation appears to now be fully gated on
Config being present, not partially degraded without it. Config was added
(`config.tf`) specifically to unblock evaluation; 15 findings appeared
within ~10 minutes of the Config recorder starting.

For an org-managed account where Config is blocked by SCP, the practical
implication is stronger than the doc suggests: you won't get a *self-
documenting gap finding*, you'll get **silence** — zero findings, full
stop. That absence of findings, correlated with an `INCOMPLETE` standards
status citing `NO_AVAILABLE_CONFIGURATION_RECORDER`, is itself the evidence
of the gap; it just has to be pulled from `get-enabled-standards` rather
than `get-findings`.

## Evidence captured

`evidence/lab-5-2/security-hub-findings.json` — 15 findings, captured via
`aws securityhub get-findings --max-results 50` after CloudTrail confirmed
`IsLogging: true` and the Config recorder had completed an initial
evaluation pass. All findings at capture time were LOW/MEDIUM severity
CloudWatch alarm-coverage gaps (e.g. missing metric filters for CloudTrail
config changes, S3 bucket policy changes, NACL changes) — expected on a
freshly-deployed account with no CloudWatch alarms configured yet.

## Cleanup

All resources here (CloudTrail trail + bucket, Config recorder + delivery
channel + bucket, Security Hub + standards subscriptions) were destroyed
the same day evidence was captured, per the lab's cost-control guidance.
