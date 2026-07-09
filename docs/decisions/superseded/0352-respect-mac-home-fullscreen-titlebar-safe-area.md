# 0352: Respect Mac Home Fullscreen Titlebar Safe Area

Date: 2026-07-08

Status: Superseded by [0355 Integrate Mac Fullscreen Traffic Lights Into Home Toolbar](0355-integrate-mac-fullscreen-traffic-lights-into-home-toolbar.md), then [0357 Integrate Mac Fullscreen Titlebar Reserve Into Toolbar](../0357-integrate-mac-fullscreen-titlebar-reserve-into-toolbar.md)

Refines: [0022 Own Mac Home Toolbar at the Split Shell](../0022-own-mac-home-toolbar-at-split-shell.md), [0341 Consolidate Mac Home Toolbar Row](../0341-consolidate-mac-home-toolbar-row.md)

Refined by: [0354 Reserve Revealed Mac Fullscreen Titlebar Space](0354-reserve-revealed-mac-fullscreen-titlebar-space.md), then superseded by [0355 Integrate Mac Fullscreen Traffic Lights Into Home Toolbar](0355-integrate-mac-fullscreen-traffic-lights-into-home-toolbar.md) and [0357 Integrate Mac Fullscreen Titlebar Reserve Into Toolbar](../0357-integrate-mac-fullscreen-titlebar-reserve-into-toolbar.md)

## Context

Mac Home intentionally uses a full-size transparent titlebar and a root-owned SwiftUI top toolbar so the app's search, mode strip, counters, and global controls align with the traffic-light band in normal windows.

In macOS fullscreen, however, the system can temporarily reveal the menu bar and native titlebar/traffic-light strip. If Home continues to ignore the top safe area in that state, the SwiftUI toolbar is drawn underneath that revealed native strip and appears covered.

## Decision

Mac Home observes whether its containing `NSWindow` is in fullscreen.

Normal windows continue to ignore the top safe area so the custom toolbar stays aligned to the traffic-light titlebar band. Fullscreen windows do not ignore the top safe area, letting macOS reserve room for the revealed system titlebar instead of covering Routina's toolbar controls.

The native window toolbar remains compact and visually transparent because Home still owns its visible top chrome.

Decision 0354 later adds a separate revealed-titlebar reserve because visual verification showed the safe area alone does not move full-size SwiftUI content out from under macOS's transient fullscreen titlebar strip.

## Consequences

- Fullscreen Home keeps the custom toolbar below the revealed macOS titlebar/menu strip.
- Windowed Home preserves the existing traffic-light-band alignment.
- Future Home chrome changes must keep fullscreen safe-area behavior separate from normal-window titlebar alignment.
