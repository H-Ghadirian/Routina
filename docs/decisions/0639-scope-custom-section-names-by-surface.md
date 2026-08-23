# 0639: Scope Custom Section Names by Surface

## Status

Accepted

## Date

2026-08-23

## Refines

- [0635: Separate Mac Settings Section Surfaces](0635-separate-mac-settings-section-surfaces.md)
- [0419: Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md)

## Context

Mac Settings presents custom sections through separate `Main task list` and
`Backlog` segments. Section creation nevertheless treated the shared catalog as
one title namespace. A name already used by the other surface could therefore
produce the duplicate-name validation message even though the person was
creating an independent destination.

## Decision

Top-level section-name uniqueness is scoped by surface. A normalized title may
appear at most once among top-level sections on the Radar (`Main task list`)
surface and once among top-level sections on the Backlog surface. Subsection
names remain unique among siblings under their parent super section; their
surface is inherited from that parent.

The storage sanitizer, create/upsert path, and rename path all apply the same
scope. Existing IDs, ordering, rules, and surface assignments are unchanged.

## Consequences

- A person can use the same organizing concept, such as `Health`, in both
  surfaces without a misleading duplicate-name error.
- Duplicate titles within one surface remain prevented, including case- and
  diacritic-insensitive variants.
- The shared catalog format remains backward compatible and requires no data
  migration.
