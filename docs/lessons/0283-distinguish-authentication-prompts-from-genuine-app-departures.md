# 0283 — Distinguish authentication prompts from genuine app departures

Date: 2026-09-01

## Symptom

With iOS App Lock enabled, a successful Face ID unlock immediately opened another Face ID prompt, repeating indefinitely instead of revealing Routina.

## Root Cause

Routina treated every inactive or background scene phase as a genuine departure. The system authentication prompt itself temporarily made the app inactive, so its return to active ran the ordinary app-return authentication path and started the next prompt.

## Fix

App Lock now tracks inactive scene transitions that occur while its own authentication attempt is running and consumes their matching active transitions without starting another attempt. A real background transition clears that exemption, locks Routina, and preserves authentication on return.

## Prevention Rule

When an app-owned system prompt changes lifecycle state, model that prompt's lifecycle transitions separately from genuine app departure and return. Never weaken the background lock path to suppress a prompt-driven inactive transition.

## Regression Safeguard

`Tests/Shared/AppLockSceneTransitionPolicyTests.swift` covers a complete authentication-prompt cycle, ordinary inactive/active behavior, multiple shared gates, and backgrounding during authentication. The App Lock regression scenario is recorded in `docs/scenarios/README.md`.
