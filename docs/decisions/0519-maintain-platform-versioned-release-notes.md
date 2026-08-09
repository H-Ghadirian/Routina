# 0519 Maintain Platform-Versioned Release Notes

Status: Accepted

Date: 2026-08-09

Refines: [0416 Use Semantic Release Versions](0416-use-semantic-release-versions.md)

## Context

Routina synchronizes its public version and build metadata across its iOS, iPadOS, watchOS, macOS, and bundled extension targets. That alignment does not mean that a feature, fix, limitation, or distribution concern is the same on every platform. The project had no durable, platform-specific place to record what was included in a particular version, which made it easy for important release scope to remain only in commit history or decision records.

## Decision

Maintain release history in docs/releases/ with one folder for macOS, iOS (iPhone), iPadOS, and watchOS. Every public version gets one Markdown document in each applicable platform folder named MAJOR.MINOR.PATCH.md.

Each document records release status, public version, Apple build number, release/snapshot date, all user-visible features and behavior changes, all user-visible bug fixes, and any known issues for that platform. iPadOS keeps its own document even while it shares the universal iOS target. Shared changes are repeated in every affected platform document so the history is useful when read independently.

Create the documents before a version is frozen for distribution, update them through release preparation, and mark them Released only after shipment. Do not infer or rewrite historical shipped scope from development commits alone; backfill older versions only from verified release evidence. Correct a material inaccuracy in a shipped note with a dated correction and record a later fix in the version where it actually ships.

## Consequences

- Every device family has a direct answer to what changed in a version.
- Release notes distinguish user-facing features, fixes, remaining issues, and internal development work.
- Version alignment stays compatible with Decision 0416 while platform-specific availability remains explicit.
- Decision records continue to explain why a product choice exists; release notes explain what changed in a version.
