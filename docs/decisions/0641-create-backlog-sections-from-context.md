# 0641 — Create Backlog sections from task context

Date: 2026-08-23

Status: Accepted

## Context

Backlog already shares the main window's search/create toolbar and keeps deliberately empty custom sections reachable. Its permanent `New super section` field duplicated section management in Settings and occupied the most useful empty-state space. A flat list of every Backlog section in a task's move menu also becomes difficult to scan as the catalog grows.

## Decision

Backlog does not render a persistent section-name composer. A person creates a Backlog super section from a task's `Move to > Backlog > New Backlog Super Section…` command in the Main task list or from the equivalent Backlog task menu. The confirmation creates the section and moves the originating task into it. Settings remains the place to create an empty section intentionally, including when no task is available.

Backlog destinations are grouped under one `Backlog` submenu in the Main task list's native move menu. Backlog super sections with subsections open one additional level; leaf super sections remain direct commands. Main task list sections stay at the first level, and the menu names the creation action `New Main Task List Super Section…` so the two surfaces are unambiguous.

The Backlog empty state explains how to move a task into Backlog or use Settings. Deliberately created empty sections remain visible so the catalog can be prepared before work is moved into it. User-facing copy calls the everyday workspace the `main task list`; `Radar` remains an internal/domain term only.

## Consequences

- Section creation is available at the moment a person has a task to organize, without adding another always-visible control.
- A new section created from a move menu is immediately useful because the selected task is assigned to it.
- Settings supports planning an empty Backlog catalog, while the Backlog workspace stays focused on reviewing and searching work.
- Menu height grows with the number of Main task list sections, but Backlog's section catalog remains behind one predictable submenu.

## Related records

- [0633](0633-make-mac-backlog-hierarchical-and-searchable.md)
- [0634](0634-unify-mac-workspace-search-and-creation.md)
- [0635](0635-separate-mac-settings-section-surfaces.md)
- [0640](0640-route-unassigned-backlog-candidates-by-tags.md)
