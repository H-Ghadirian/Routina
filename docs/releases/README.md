# Release History

This directory is Routina's release-history source of truth. It records what shipped, or is currently planned to ship, for each public version and each Apple platform.

Routina aligns its public semantic version and Apple build number across its iOS, iPadOS, watchOS, macOS, and bundled extension targets, including targets retained for a later distribution phase. The release notes remain separate because the available UI, features, changes, fixes, distribution status, and known issues can differ by platform. See [Decision 0416](../decisions/0416-use-semantic-release-versions.md) for version numbering, [Decision 0519](../decisions/0519-maintain-platform-versioned-release-notes.md) for this documentation convention, and [Decision 0568](../decisions/0568-defer-watch-companion-from-first-production-release.md) for the phase-one Watch deferral.

## Platform histories

- [macOS](macos/README.md)
- [iOS (iPhone)](ios/README.md)
- [iPadOS](ipados/README.md)
- [watchOS](watchos/README.md)

iPadOS uses the universal iOS app target today, but it has its own notes so an iPad-specific addition, regression, or limitation is never hidden inside the iPhone release notes.

## Updating a version

Create docs/releases/<platform>/<MAJOR.MINOR.PATCH>.md before the version is frozen for distribution. Use the same public version and build number that will appear in that platform's bundle metadata.

Each entry must contain:

- Release status and date (or the date the in-development snapshot was last reviewed).
- The public version and Apple build number.
- Every user-visible feature and behavior change for that platform.
- Every user-visible bug fix for that platform.
- Known issues that remain at release time. Do not describe an issue as fixed until the fix is verified.
- Links to the relevant decision records, lessons, tests, or source commits when they make the history auditable.

Use concise, user-facing language. Internal refactors, generated files, and release mechanics do not need standalone bullets unless they affect users, privacy, reliability, distribution, or compatibility. Shared changes belong in each affected platform's document; a reader should not have to infer whether a change applies to their device.

Do not silently rewrite shipped notes. Correct material inaccuracies in place with a dated correction, and place a later fix in the later version where it shipped.

## Current baseline

Formal platform release notes begin with the 1.3.1 / build 8 snapshot recorded on 2026-08-09. The Watch companion is explicitly deferred from this first production phase rather than marked as shipping. Older public versions are not backfilled here yet because the repository does not preserve verified release cutoffs and release-note scope for them. They should be backfilled only from a verified App Store, TestFlight, release branch, or release-manager source rather than guessing from development commits.
