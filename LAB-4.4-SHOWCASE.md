# Lab 4.4 — Evidence That Defends Itself: Keyless Signing + Chain of Custody

## What This Is

Lab 4.3 built a pipeline that produces evidence. Lab 2.5 built a vault nobody can quietly edit. This lab joins them: every PR run now cryptographically signs its own evidence using Sigstore's keyless signing, uploads a bundle + hash + signature + receipt to the immutable vault, and ships a script an auditor can run to get one of two answers — `CHAIN INTACT`, or an exact reason it isn't. No private key exists anywhere to manage, rotate, or leak.

## How Keyless Signing Actually Works

The workflow already has a GitHub OIDC identity (from Lab 4.3's AWS trust). Cosign reuses that same token to prove "this signature came from this repository's workflow, at this exact moment" to Sigstore's certificate authority (Fulcio), which issues a certificate that's valid for minutes, not years. Sigstore's public transparency log (Rekor) timestamps the signature permanently. Nothing is stored in AWS or GitHub secrets — the trust lives entirely in short-lived, publicly-verifiable infrastructure neither I nor an AWS admin on this account controls.

## The Four Properties, Each With a Real Artifact

| Property | Proven by |
|---|---|
| Authenticity | Fulcio certificate inside the `.sig.bundle`, tied to this repo's OIDC identity |
| Integrity | `.sha256` sidecar + the signature, both computed over the exact same bytes |
| Timeliness | The Rekor log entry, timestamped independently of anyone's word |
| Preservation | S3 Object Lock retention on the exact version ID in `receipt.json` |

Full mapping with commands in `WRITEUP.md`.

## Proof, End to End

A real run (`33679256358`) produced four files in the vault:
```
evidence-33679256358-<sha>.tar.gz          the bundle
evidence-33679256358-<sha>.tar.gz.sha256   integrity sidecar
evidence-33679256358-<sha>.tar.gz.sig.bundle   Cosign signature + Fulcio cert + Rekor ref
receipt.json                                pointer: run, vault, key, version ID, hash
```
Running the verify script from a laptop, with zero manual vault-path copying:
```
$ EVIDENCE_VAULT=cgep-lab-grc-evidence-vault-5d1c4c6d bash scripts/verify-evidence.sh 33679256358 --profile sandbox
...
Verified OK
CHAIN INTACT for run 33679256358
```

## The Tamper Test — and an Honest Correction

Downloaded the bundle, appended a byte, re-hashed: the hash changed completely, and `cosign verify-blob` rejected it outright (`bundle="c1cadd02..." payload="856489..."`). That part matched the lab exactly.

Then I actually ran the "try to overwrite the vault" step the lab describes — and the result was more interesting than the lab's text suggests. Object Lock did **not** reject the write. S3 versioning meant the tampered copy silently became the *new latest version* at that key, while the original signed version stayed intact underneath, protected by its own retention lock. The lab's claim ("Object Lock refuses to overwrite the existing key") isn't quite how S3 versioning behaves — what's actually true, and what I confirmed live, is narrower and more precise: **the original signed version can never be deleted or altered, and any receipt-pinned or hash/signature check against it still catches tampering immediately, even if a naive "grab the latest object" call wouldn't.** I restored the correct version as current before moving on, and the verify script confirmed `CHAIN INTACT` again immediately after.

That distinction — between "nothing can ever be overwritten" and "what was signed can never be destroyed, and checking against it always tells the truth" — is exactly the kind of nuance a real audit review exists to surface instead of taking a docs page's word for it.

## Why It Matters

An assessor no longer needs to trust that I ran the right checks and reported honestly. They run one script against a run ID and get math back: a hash match, a valid signature from a certificate tied to my repository, a timestamp from a log neither of us controls, and a retention date enforced by S3 itself. That's chain of custody as an engineered property, not a claim in a policy document.

## Stack

`Sigstore (Cosign, Fulcio, Rekor)` · `GitHub Actions OIDC` · `AWS S3 Object Lock` · `Terraform` · `NIST 800-53`

---

### Suggested post caption

> Wired keyless signing into my compliance pipeline today — every PR run now signs its own evidence with Sigstore, no private key anywhere to manage or leak, and uploads a signed, hashed, receipted bundle to an immutable vault. Built the verify script an auditor runs to get "CHAIN INTACT" back in seconds. Then I actually ran the tamper test instead of trusting the lab's description of it, and found the real behavior was more nuanced than advertised: S3 Object Lock doesn't block a new write to the same key, it just guarantees the *original signed version* survives underneath, retained and checkable, no matter what gets written on top. That's the difference between reading a control description and actually testing it.
>
> #GRC #ChainOfCustody #Sigstore #Cosign #DevSecOps #AWS #NIST80053

### Visual idea

A vertical "chain" diagram with four linked rings labeled Authenticity, Integrity, Timeliness, Preservation, each annotated with its proving artifact (Fulcio cert / SHA-256 / Rekor entry / Object Lock retention). Below it, a small terminal card showing the final `CHAIN INTACT for run 33679256358` line in green monospace.
