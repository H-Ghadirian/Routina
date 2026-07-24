# 0009 — Never Install Empty Mac Context Menus

Date: 2026-07-24

## Symptom

Right-clicking an ordinary section or group header in the production Mac Home
sidebar locked the app, showed the spinning wait cursor, and consumed a full CPU
core.

## Root Cause

Every section and group header installed a SwiftUI `contextMenu` modifier even
when its beta-gated builder produced no menu items. On macOS 26.5, opening that
empty context menu could trap SwiftUI's AttributeGraph in a continuous update
loop inside the AppKit menu event loop.

## Fix

Section and group headers now install the context-menu modifier only when their
current state provides at least one action. Future and custom sections retain
their management actions, and focus-timer menus remain available when their
beta setting is enabled.

## Prevention Rule

On macOS, conditionally attach `contextMenu` itself. Do not attach the modifier
unconditionally and rely on an empty `@ViewBuilder` result to disable it.

## Regression Safeguard

The macOS performance regression suite verifies that section and group headers
gate context-menu attachment with explicit action-availability predicates.
