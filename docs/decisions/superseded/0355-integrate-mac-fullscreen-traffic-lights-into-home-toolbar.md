# 0355: Integrate Mac Fullscreen Traffic Lights Into Home Toolbar

Date: 2026-07-08

Status: Superseded by [0357 Integrate Mac Fullscreen Titlebar Reserve Into Toolbar](../0357-integrate-mac-fullscreen-titlebar-reserve-into-toolbar.md)

Supersedes: [0352 Respect Mac Home Fullscreen Titlebar Safe Area](0352-respect-mac-home-fullscreen-titlebar-safe-area.md), [0354 Reserve Revealed Mac Fullscreen Titlebar Space](0354-reserve-revealed-mac-fullscreen-titlebar-space.md)

Refines: [0022 Own Mac Home Toolbar at the Split Shell](../0022-own-mac-home-toolbar-at-split-shell.md), [0341 Consolidate Mac Home Toolbar Row](../0341-consolidate-mac-home-toolbar-row.md)

## Context

Mac Home draws a root-owned SwiftUI toolbar instead of relying on visible native toolbar items. The toolbar already has a reserved leading region for macOS traffic lights, and the Home split/sidebar content is intended to start below that toolbar.

Decision 0352 made fullscreen Home respect the top safe area, and decision 0354 added pointer-driven revealed-titlebar spacing. In practice, the pointer-driven spacing made the whole Home layout jump when the pointer reached or left the top edge, and the intermediate states could show the sidebar's rounded top surface behind the traffic lights.

The desired fullscreen behavior is closer to Xcode's integrated titlebar treatment: the native traffic lights occupy the leading edge of the app's top chrome row, Routina controls start after that traffic-light region, and the sidebar/content stay below the custom toolbar row.

## Decision

Mac Home uses its existing SwiftUI top toolbar as the stable titlebar chrome row in both normal windows and fullscreen.

Home ignores the top safe area for that shell in fullscreen just as it does in normal windows. It does not observe the pointer-revealed native titlebar state, poll the mouse location, or add/remove fullscreen top padding while the pointer moves.

The custom toolbar keeps its leading traffic-light reserve, and the split/sidebar content remains padded below the toolbar height. The native window toolbar stays compact and visually transparent so it does not paint a separate opaque strip over Routina's toolbar.

## Consequences

- Moving the pointer to the top of a fullscreen window does not move Routina's Home layout up or down.
- The top-left fullscreen traffic-light area belongs to macOS, while Routina toolbar controls begin after the reserved leading region.
- The Home sidebar and main content remain below the custom toolbar row instead of appearing underneath the traffic lights.
- Future Mac Home toolbar controls must continue to respect the leading traffic-light reserve instead of relying on pointer-driven fullscreen offsets.
