# 0220: Nest Sleep and Gate Mac Event and Emotion Actions

## Status

Accepted

## Date

2026-06-12

## Supersedes

- [0070: Include Sleep in the Mac Add Menu](superseded/0070-include-sleep-in-mac-add-menu.md)

## Refines

- [0154: Present Mac Away Start Inline](0154-present-mac-away-start-inline.md)
- [0194: Keep Event Capture Generic](0194-keep-event-capture-generic.md)
- [0218: Hide Mac Timeline Quick Filters Behind Beta Toggle](0218-hide-mac-timeline-quick-filters-behind-beta-toggle.md)

## Context

The Mac Home sidebar Add menu has grown into a mix of capture types and session actions. Event and Emotion are still useful, but they add more top-level choices and matching Timeline filter options to the default Mac surface. Sleep is also a protected-mode session, but presenting it beside Away makes the Add menu harder to scan even though Sleep and Away are related "step away" flows.

Routina already uses Settings -> General -> Beta Experiments to keep optional or still-stabilizing Mac surfaces available without making default release UI dense.

## Decision

The default Mac Home sidebar Add menu shows Note, Goal when Goals are enabled, Task, Check In, and Away. It does not show Event, Emotion, or Sleep by default.

Event and Emotion creation actions are controlled by the local `appSettingMacEventEmotionActionsEnabled` beta flag in Settings -> General -> Beta Experiments. When the flag is off, Mac Timeline type-filter controls also omit Events and Emotions, and any saved Events or Emotions filter normalizes back to All in Mac Timeline surfaces.

Sleep remains implemented as its own protected session mode, but the Mac Home entry point moves under the inline Away start surface as a secondary `Start Sleep` action. Starting Sleep still uses the existing Mac sleep starter and active-focus warning behavior rather than creating an Away session.

## Consequences

- The default Mac Add menu is shorter and keeps Sleep visually grouped with Away.
- Users can opt back into Event and Emotion creation and filtering from Beta Experiments.
- Existing Event and Emotion records remain readable in Timeline and detail surfaces; only the default top-level creation and filter choices are gated.
- Sleep data, blocking behavior, and planner/timeline semantics remain separate from Away data.
