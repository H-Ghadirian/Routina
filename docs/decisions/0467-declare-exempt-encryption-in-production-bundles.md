# 0467: Declare Exempt Encryption in Production Bundles

Status: Accepted

Date: 2026-08-01

Refines: [0466 Harden App Store Release Surfaces](0466-harden-app-store-release-surfaces.md)

## Context

App Store Connect marked every newly uploaded Routina build as `Missing Compliance` because the production bundles did not declare their export-compliance status. Review of the current implementation found only Apple-provided HTTPS, Keychain/Security, and CryptoKit SHA-256 use for OAuth PKCE. Routina does not currently implement or bundle non-exempt encryption.

Answering the questionnaire manually for each build is avoidable when the declaration is stable and encoded in the shipped bundle.

## Decision

The macOS and iOS production Info.plists set `ITSAppUsesNonExemptEncryption` to `false`. This declares that the current release does not use non-exempt encryption and lets App Store Connect reuse that answer for future uploads.

Before adding custom cryptography, an encrypted communications product, VPN functionality, or a dependency that provides non-exempt encryption, the release owner must reassess the export classification. If the classification changes, the bundle declaration and any required Apple documentation or compliance code must be updated before upload.

## Consequences

- Future production uploads should no longer stop at `Missing Compliance` for the current encryption use.
- Builds uploaded before this declaration, including build 5, still require the one-time answer in App Store Connect.
- Both platform production plists are covered by a regression test so a target cannot silently lose the declaration.
- The next upload uses build 6 because App Store Connect has already received build 5; the marketing version remains 1.2.0.
