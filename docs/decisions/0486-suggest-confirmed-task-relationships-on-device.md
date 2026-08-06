# 0486: Suggest Confirmed Task Relationships On Device

## Status

Accepted

## Date

2026-08-06

## Refines

[0409 Add Manual Can-Complete Task Links](0409-add-manual-can-complete-task-links.md),
[0472 Broker Local AI Access Through an App-Owned Snapshot](0472-broker-local-ai-access-through-an-app-owned-snapshot.md),
and [0481 Learn Task-Choice Tie-Breaks After Metadata Readiness](0481-learn-task-choice-tie-breaks-after-metadata-readiness.md)

## Context

Routina already stores typed task relationships and resolves inverse links, but
people must currently discover and create every link manually. With a large task
list, prerequisites and related work are easy to miss. Automatically writing
model guesses would make a person's task graph and recommendations unreliable.

## Decision

Task Details on iOS and macOS keeps the manual linked-task controls and adds an
on-demand `Suggest` action. The action uses Apple's on-device Foundation Models
when available. Task data stays inside the app's model session; the read-only
MCP snapshot remains independent and no external helper receives write access.

macOS also provides a dedicated `Review Task Relationships` window from the
application menu. The window loads immutable presentation rows for every active,
reviewable task and tracks durable device-local review progress. The person can analyze only
the selected task, analyze only new or relationship-relevant changed tasks, or
explicitly choose `Reanalyze all tasks`. Opening the window never starts analysis
or submits the database automatically.

The Mac app stores a versioned, device-local SHA-256 fingerprint of the bounded
task summary used for relationship analysis. A missing fingerprint means `New`;
a different fingerprint means `Changed`. Priority, importance, urgency, pressure,
learned ranking, completion history, and other excluded fields do not invalidate
relationship review. A task receives its current fingerprint only after analysis
finds no proposal or the person resolves every proposal by confirmation or
dismissal. Failed and unresolved tasks remain pending. Pending model output is not
persisted, so closing the window before resolving it makes that task eligible for
analysis again. Deleted/inactive task entries are pruned when the catalog loads.

An explicit all-task run builds one immutable task-summary catalog, then analyzes
active source tasks sequentially rather than launching concurrent model calls.
It shows the current task, completed count, and proposal count, and can be stopped
without discarding proposals already found. The review queue keeps at most one
proposal for an unordered task pair. Every proposal remains editable and requires
individual confirmation; a batch run never writes relationships by itself.
An error caused by one task's content is recorded against that task and the batch
continues; affected rows remain unchecked and explicitly need retry. Only
cancellation, catalog failure, or unavailable Apple Intelligence stops the whole
run because those conditions prevent useful remaining requests.

The request includes the source task and at most 12 active, unlinked candidates.
Each bounded summary can include its title, description, tags, custom-section
path, deadline, planned date, availability window, limited schedule description,
and up to five steps and checklist items. Candidates with shared normalized tags,
path components, or work words are considered first so richer model context
remains bounded for large databases. A shared path improves candidate discovery
but never proves a dependency on its own. Priority, importance, urgency, pressure,
learned choice scores, notes, attachments, comments, and history are not included
because they do not establish task structure. Every supplied field is treated as
untrusted data. Model output is also untrusted: Routina accepts only known
candidate IDs, `Blocked by`, `Blocks`, or `Related`, nonempty bounded reasons,
and at most five unique suggestions. Allowing `Blocks` lets a new or changed
source task reveal that it is a prerequisite for an unchanged existing task,
without rerunning every unchanged task as a source.

A suggestion never changes either task. The person may change its relationship
type, including reversing dependency direction with `Blocks`, dismiss it, or
confirm it. Confirming routes through the existing
app-owned task-relationship mutation and inverse-link behavior. Manual linking
remains available when Apple Intelligence is unavailable or the desired task is
outside the bounded candidate set.

A confirmed `Blocked by` relationship makes the dependent task unavailable to
compact iOS `Help me choose` while its prerequisite is unresolved. The exclusion
happens before metadata-readiness counts, comparisons, and ranking. A completed
current occurrence, completed one-off task, or canceled one-off prerequisite no
longer blocks the dependent task.

## Consequences

- AI can reduce relationship setup without becoming an authority over task data.
- Confirmation and editable relationship types make every persisted link
  explicit and reviewable.
- The Mac review window makes catalog-wide progress visible without turning app
  launch or window opening into an unbounded AI scan.
- A user-started all-task run can take time on a large catalog, but sequential
  calls, cancellation, reusable immutable summaries, and bounded per-task prompts
  prevent a concurrent model storm or repeated SwiftData decoding.
- Normal review work scales with new and relationship-relevant changed tasks;
  full reanalysis remains an explicit recovery or reconsideration action.
- Review fingerprints are local derived state rather than synced task metadata;
  task relationships themselves still use the normal persistence and sync path.
- Help me choose does not recommend work that cannot start yet or demand missing
  metadata for that blocked work.
- Bounded candidate selection protects the task-detail interaction from a
  whole-database model prompt, while manual linking covers omitted candidates.
- Task paths and concrete work items improve relationship discovery without
  turning organizational proximity into an automatic relationship.
