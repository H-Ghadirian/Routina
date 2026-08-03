# 0075 — Enforce hidden features at the preference boundary

Date: 2026-08-03

## Symptom

The production app could reveal Beta Experiments through a hidden Settings gesture, and its signed Mac bundle declared sensitive entitlements for unfinished features that were not visible in the ordinary release flow.

## Root Cause

Experiment availability was treated primarily as a presentation choice. Hiding a toggle by default did not prevent a stored preference from enabling the feature, and the production entitlement set continued to cover development-only implementations.

## Fix

The Beta Experiments panel is now development-only. A central policy forces every experimental Boolean preference off in production, including restored values, and production bundle configurations no longer declare location, microphone, or Apple Events access for those hidden features.

## Prevention Rule

Gate unfinished features at both the UI boundary and the underlying preference or dependency boundary. Production entitlements and purpose strings must describe only functionality a reviewer can reach in the submitted build.

## Regression Safeguard

Decision [0470](../decisions/0470-keep-beta-experiments-out-of-production.md), the Production Experiment Lockdown scenario, and `AppStoreComplianceConfigurationTests` verify the policy, Settings visibility, entitlements, and purpose strings.
