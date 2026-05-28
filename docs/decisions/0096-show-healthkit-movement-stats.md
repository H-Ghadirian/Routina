# 0096: Show HealthKit Movement Stats in iOS Stats

- Status: Accepted
- Date: 2026-05-28

## Context

Routina's Stats dashboard already summarizes routines, focus, notes, emotions, events, goals, and optional Git activity. Users also expect personal movement context such as steps and active calories to sit near those daily-life stats, but Health data requires explicit user permission and is only available through HealthKit on supported devices.

## Decision

Routina for iOS can optionally read Apple Health movement data from HealthKit after the user taps Connect Health in Stats. The Stats dashboard reads step count, active energy burned, walking/running distance, and Apple exercise time for the selected Stats range and presents them as factual summary cards.

Routina requests read-only Health access. It does not write Health samples, persist raw Health samples into SwiftData, or sync Health values through Routina's CloudKit data. Health values are queried on demand for display.

## Consequences

- iOS targets include the HealthKit entitlement and a Health data usage description.
- Health access starts from a user-initiated Stats action instead of prompting during launch.
- macOS Stats remains unchanged because HealthKit movement data is an iOS device capability for this product surface.
- Future Health metrics should stay factual and permission-scoped unless a separate decision adopts deeper health insights or persistence.
