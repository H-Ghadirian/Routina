# 0038: Configure Home Task Row Fields

## Status

Accepted

## Date

2026-05-14

## Context

The Home task row had accumulated several useful signals: icon, row number, status, schedule, priority, pressure, progress, steps, places, tags, and goals. Different users and workflows need different density, especially on smaller iPhone screens and in the Mac sidebar.

## Decision

Routina lets users choose which Home task row fields are visible from Settings > Appearance > Task Row. The preference is stored as hidden row fields so the default remains the full existing row and future fields can default to visible.

Both iOS and macOS Home list rows consume the same visibility model. Metadata generation respects the field choices before joining text fragments, so hiding priority, pressure, progress, steps, schedule, or place data removes those fragments without leaving dangling separators.

## Consequences

- The default Home row stays unchanged for existing users.
- Appearance settings own row density because the choice changes presentation, not task data.
- New row fields should be added to `HomeTaskRowField` and default to visible unless there is a product reason to hide them.
- Platform-specific rows may ignore fields they do not render, but shared metadata fields should honor the visibility model consistently.
