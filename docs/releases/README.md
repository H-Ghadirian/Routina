# Release History

This directory is Routina's release-history source of truth. It records what shipped, or is currently planned to ship, for each public version and each Apple platform.

Routina aligns its public semantic version and Apple build number across shipping targets and targets retained for a later distribution phase. The release notes remain separate because the available UI, features, changes, fixes, distribution status, and known issues can differ by platform. Versioned App Store metadata separately preserves the exact public listing copy. See [Decision 0416](../decisions/0416-use-semantic-release-versions.md) for version numbering, [Decision 0519](../decisions/0519-maintain-platform-versioned-release-notes.md) for platform release notes, [Decision 0704](../decisions/0704-maintain-versioned-app-store-metadata.md) for App Store copy, [Decision 0568](../decisions/0568-defer-watch-companion-from-first-production-release.md) for the phase-one Watch deferral, and [Decision 0709](../decisions/0709-defer-ipad-support-until-it-is-ready.md) for the iPad deferral.

## Platform histories

- [macOS](macos/README.md)
- [iOS (iPhone)](ios/README.md)
- [iPadOS](ipados/README.md)
- [watchOS](watchos/README.md)

iPadOS is outside the current release scope. Its notes preserve deferred planning history without implying that retained adaptive source is supported or ready to ship.

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

Store App Store listing copy in a companion
`docs/releases/<platform>/<MAJOR.MINOR.PATCH>-app-store.md` document. Preserve
the exact Description and What's New text for that version, plus Promotional
Text or other public fields when used. Draft copy follows its platform release
note; submitted copy becomes historical and is not overwritten for a later
release. Record missing historical fields as unverified instead of recreating
them from source history.

The combined iPhone and macOS submission work, including the recorded iPad
deferral, for the current candidate is
tracked in the [1.4.0 App Store submission checklist](1.4.0-app-store-submission.md).

## Current baseline

The current release candidate is 1.4.0 / build 13. Its notes supersede the
unreleased 1.3.1 / build 8 draft and retain the verified 1.2.0 source boundary.
The iPad app and Watch companion are explicitly deferred from this first
production phase rather than marked as shipping. Older public versions are not backfilled here
yet because the repository does not preserve verified release cutoffs and
release-note scope for them. They should be backfilled only from a verified App
Store, TestFlight, release branch, or release-manager source rather than guessing
from development commits.
