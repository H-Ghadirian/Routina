# 0513: Defer iOS Screen Time Blocking Until Distribution Approval

## Status

Accepted

## Date

2026-08-09

## Refines

[0085: Shield Apps and Websites During Focus](0085-shield-apps-and-websites-during-focus.md)

## Context

Routina's iOS app and website blocking uses the Family Controls and Managed Settings frameworks. The implementation is retained for internal development, but Apple has not yet assigned the Family Controls distribution capability to the production App ID. A production archive therefore cannot be signed, and shipping the dormant UI would conflict with App Review's requirement that shipped functionality be available and documented.

## Decision

The iOS development target retains the Family Controls entitlement and compiles the blocking implementation behind the `ROUTINA_IOS_FAMILY_CONTROLS` condition. The iOS production target does not define that condition, omits the Family Controls entitlement, and does not render the Blocking Settings entry or compile the Screen Time implementation.

The source remains in the repository. When Apple assigns the Family Controls distribution capability, restoring the production compilation condition and entitlement is an explicit release decision that must be verified with a newly generated App Store provisioning profile. macOS blocking is unchanged.

## Consequences

- The current iOS production archive can be distributed without requesting an unapproved Family Controls entitlement.
- Development builds remain able to test Screen Time authorization, selected-app shielding, and website blocking.
- The production binary has no hidden or dormant iOS Screen Time feature.
- Re-enabling iOS blocking for production requires deliberate signing and review verification after Apple approves the capability.
