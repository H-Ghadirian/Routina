# 0061: Share Stable Routina Deep Links

## Status

Accepted

## Date

2026-05-26

## Context

Tasks already use app-owned Routina URLs for notifications and focus surfaces. Users also need a lightweight way to share or save direct links to a task, goal, or standalone note, then return to the exact item from outside the app.

These links should not depend on public web infrastructure or CloudKit sharing. They should be stable app links that route locally to records the signed-in app already has.

## Decision

Routina uses `routina://task/<uuid>`, `routina://goal/<uuid>`, and `routina://note/<uuid>` as stable in-app entity links. Existing sprint links keep using `routina://sprint/<uuid>`.

Task, goal, and note detail surfaces expose link sharing and copying. Opening a task link selects Home and opens that task, opening a goal link selects Goals and navigates to that goal, and opening a note link selects Timeline and presents the note detail.

## Consequences

- Shared entity links remain app-owned and portable across Apple system share sheets without requiring a Routina web endpoint.
- Links are meaningful only on devices where Routina is installed and the referenced record exists.
- Future entity types should extend the centralized `RoutinaDeepLink` model instead of adding separate URL parsing paths.
