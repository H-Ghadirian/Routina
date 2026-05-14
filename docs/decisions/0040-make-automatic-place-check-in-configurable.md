# 0040: Make Automatic Place Check-In Configurable

## Status

Accepted

## Date

2026-05-14

## Context

Automatic saved-place check-ins create useful passive place history, but users need direct control over whether Routina should mutate check-in history from device location changes.

## Decision

Settings > Places exposes an Auto check-in toggle. The setting defaults on so the accepted automatic saved-place behavior remains available for existing users.

When the setting is off, Routina does not start automatic saved-place check-ins from Home or Places map location refreshes. Turning the setting off ends an active automatic check-in, but leaves manually started check-ins untouched.

## Consequences

- Users can keep saved places for routine filtering and manual check-ins without allowing passive check-in history.
- Manual map and saved-place check-in controls remain available when automatic check-in is disabled.
- Automatic sessions remain visibly distinct and confirmable when the setting is enabled.
