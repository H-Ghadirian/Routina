# 0221: Hide Stats Sleep Tab Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Context

The Sleep dashboard scope adds a dedicated way to focus on Sleep cards and Sleep-related history in Stats, but it can increase default surface complexity on smaller layouts and is still an optional analysis view.

Routina already uses Settings -> General -> Beta Experiments for user-optional surfaces and scope surfaces that are useful for focused workflows while keeping the default experience quieter.

## Decision

The Stats Sleep tab is hidden by default and can be re-enabled from Settings -> General -> Beta Experiments using the `appSettingStatsSleepTabEnabled` setting.

## Consequences

- Default Stats navigation remains focused on Focus and existing core scopes.
- Sleep remains available in the broader dashboard data model and can be shown again when the beta toggle is enabled.
- The same preference key is used on iOS and macOS to keep scope visibility behavior aligned across platforms.
