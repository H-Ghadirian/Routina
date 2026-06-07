# 0172: Hide Battery Routines Until Enabled

## Status

Accepted

## Date

2026-06-07

## Context

Routina can create managed charge routines such as Charge Mac and Charge iPhone from local device battery readings. These routines are useful for users who want battery prompts, but they add tasks that the user did not explicitly create.

The previous default enabled battery routine monitoring, so a managed charge routine could appear by default. Disabling the setting only cleared the urgent low-battery presentation, leaving existing managed routines in the task list.

## Decision

Battery routine monitoring is opt-in. The `Create charge routines` setting defaults off, and managed charge routines are removed while the setting is off.

When the setting is enabled, Routina may create the appropriate managed routine for the reporting device and update its low-battery presentation using the configured threshold. Turning the setting off removes Routina-managed battery routines and their related generated rows.

## Consequences

- Charge Mac, Charge iPhone, and other device charge routines do not appear unless the user enables the feature.
- Existing generated charge routines are cleaned up on the next battery preference refresh while the feature is disabled.
- Re-enabling the feature recreates managed battery routines as needed from fresh device battery snapshots.
