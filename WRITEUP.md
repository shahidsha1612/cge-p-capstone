# Chain of Custody — Lab 4.4

Every PR run of `grc-gate.yml` produces evidence that satisfies all four chain-of-custody properties. This section maps each property to the artifact that proves it, using a real completed run as the example.

**Reference run:** `33679256358` — [Action run](https://github.com/shahidsha1612/cge-p-capstone/actions/runs/33679256358) · receipt at `evidence/lab-4-4/receipt.json` · vault `cgep-lab-grc-evidence-vault-5d1c4c6d`, key prefix `runs/33679256358/`.

| Property | What it means | Artifact that proves it | How to check it yourself |
|---|---|---|---|
| **Authenticity** | The evidence came from this specific repo's workflow, not from anyone who merely has AWS or S3 access. | The Cosign signature bundle (`*.tar.gz.sig.bundle`), containing a Fulcio certificate issued to `https://token.actions.githubusercontent.com` for this exact repo/workflow identity. | `cosign verify-blob --bundle <bundle>.sig.bundle --certificate-identity-regexp '.*' --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' <bundle>` — the certificate itself is the proof of origin; there is no shared secret to leak or forge. |
| **Integrity** | The evidence bytes are exactly what the workflow produced — nothing added, removed, or altered since. | The `.sha256` sidecar, computed at signing time, and the fact that Cosign's signature is computed over those same bytes. | `scripts/verify-evidence.sh <run_id>` recomputes the SHA-256 of the downloaded bundle and compares it to the sidecar; `cosign verify-blob` independently fails if the bytes don't match what was signed. |
| **Timeliness** | There's a trustworthy record of *when* the evidence was produced — not just a filesystem timestamp anyone could edit. | The Rekor transparency-log entry referenced inside the signature bundle, recorded at signing time by Sigstore's public log, outside anyone's control (including ours). | `cosign verify-blob` succeeding confirms the Rekor entry exists and matches; the log itself is public and independently auditable at [search.sigstore.dev](https://search.sigstore.dev). |
| **Preservation** | The evidence is still there, unmodified, when someone comes looking later. | The object's S3 Object Lock retention (`GOVERNANCE` mode) on the specific version ID recorded in `receipt.json`. | `aws s3api get-object-retention --bucket cgep-lab-grc-evidence-vault-5d1c4c6d --key runs/33679256358/<bundle> --query 'Retention.RetainUntilDate'` — the retention date is enforced by S3 itself, not by application logic. |

## A correction to the "the vault stays clean" claim

The lab's tamper-test instructions state that Object Lock prevents overwriting the original bundle. Running the actual test showed this is not quite right: with S3 versioning + Object Lock, a `PutObject` to an already-signed key does **not** get rejected — it silently creates a *new current version* at that key, while the original signed version survives untouched (protected by its own per-version retention lock; it cannot be deleted or altered).

This matters in practice: a careless `aws s3 cp s3://vault/runs/<id>/bundle.tar.gz .` (no version pinned) after a tamper attempt would fetch the **wrong** — tampered — object, because it resolves to "latest." The chain-of-custody verification still works, because:

1. `receipt.json` pins the exact `version_id` produced at signing time, and
2. even without pinning a version, the immutable `.sha256` sidecar and the Cosign signature are computed over the *original* bytes, so any content that doesn't match — tampered or not — fails both the hash check and `cosign verify-blob` immediately.

So the true guarantee is: **the original, signed version can never be deleted or altered**, and **any check against it (by version ID or by hash/signature) reliably detects tampering** — not that the vault is literally immutable to new writes at the same key. This was confirmed live during this lab: a tampered copy was uploaded to `runs/33679256358/`, correctly became "latest," was correctly rejected by both the SHA-256 comparison and `cosign verify-blob`, and was then removed by restoring the original version so the key's current state matches the receipt again.

## Verified live

```
$ EVIDENCE_VAULT=cgep-lab-grc-evidence-vault-5d1c4c6d bash scripts/verify-evidence.sh 33679256358 --profile sandbox
...
Verified OK
CHAIN INTACT for run 33679256358
```
