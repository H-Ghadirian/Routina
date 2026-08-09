# 0114 — Gate every production-excluded platform branch

Date: 2026-08-09

## Symptom

The iOS production Release build failed after Family Controls was made development-only. `FocusShieldSupport.clearCurrentBlocking()` still compiled a call to the excluded `clearShield()` helper.

## Root Cause

The implementation used several independent `#if os(iOS) && canImport(FamilyControls)` branches. One branch was missed while adding the development-only compilation condition, leaving a compiled call to a helper whose declaration had been excluded.

## Fix

Every iOS Family Controls branch in `FocusShieldSupport` now requires `ROUTINA_IOS_FAMILY_CONTROLS`, including the clearing path. The production compliance test rejects any remaining ungated iOS Family Controls conditional.

## Prevention Rule

When a platform capability is excluded from a build variant, apply its variant condition to every import, declaration, helper call, and cleanup path. Review the complete capability boundary rather than only its entry point.

## Regression Safeguard

`AppStoreComplianceConfigurationTests.iOSProductionDefersFamilyControlsUntilDistributionApproval` verifies the development-only condition and rejects the former ungated Family Controls conditional. The iOS production Release build compiles the excluded path.
