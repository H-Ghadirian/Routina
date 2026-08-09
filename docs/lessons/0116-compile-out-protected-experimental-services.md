# 0116 — Compile out protected experimental services

Date: 2026-08-09

## Symptom

The production iOS app omitted the Places UI and location purpose string, but still compiled `CLLocationManager` authorization and location-request APIs from the dormant experiment.

## Root Cause

Runtime preference gates protect visible behavior, but they do not remove protected platform APIs from a signed binary. This creates a mismatch between the released product surface and its compiled capability footprint.

## Fix

Added the development-only `ROUTINA_IOS_LOCATION_SERVICES` condition. The real `OneShotLocationProvider` now compiles only in the iOS development target; production uses a no-op `LocationClient` snapshot.

## Prevention Rule

For a protected platform service that is intentionally unavailable in production, pair the release UI and preference gates with a production compilation gate around the API implementation itself.

## Regression Safeguard

`AppStoreComplianceConfigurationTests.iOSProductionCompilesOutLocationServicesUntilPlacesShips` verifies the production/development privacy configuration, compilation condition, guarded provider, and production no-op client.
