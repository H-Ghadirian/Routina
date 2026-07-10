# 0357: Integrate Mac Fullscreen Titlebar Reserve Into Toolbar

Date: 2026-07-09

Status: Accepted

Supersedes: [0356 Reserve Stable Mac Fullscreen Titlebar Space](superseded/0356-reserve-stable-mac-fullscreen-titlebar-space.md)

Refines: [0022 Own Mac Home Toolbar at the Split Shell](0022-own-mac-home-toolbar-at-split-shell.md), [0340 Use SwiftUI Outlook-Style Mac Home Top Toolbar](0340-use-swiftui-outlook-style-mac-home-top-toolbar.md), [0341 Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

Refined by: [0362 Place Mac Sidebar Toggle Below Traffic Lights](0362-place-mac-sidebar-toggle-below-traffic-lights.md)

## Context

Decision 0356 stopped the fullscreen pointer-driven jump by reserving a stable native-titlebar-height area above Routina's SwiftUI toolbar. Visual verification showed that this fixed the rounded sidebar/split-view backing behind the native traffic lights, but it also created an ugly dead band between the macOS fullscreen chrome and Routina's actual toolbar/content.

The desired behavior is closer to Outlook/Xcode-style integrated chrome: the native traffic-light area belongs to macOS, Routina's own top toolbar remains the app chrome row, and the app does not insert a separate blank vertical strip just because the window is fullscreen.

## Decision

Mac Home observes only whether its window is fullscreen.

When Home is fullscreen, it must not add a separate fullscreen-only vertical reserve above the SwiftUI toolbar. The existing Home top toolbar row is the stable chrome row for the fullscreen session. Most Routina controls start after the native traffic-light region through toolbar leading padding; [0362](0362-place-mac-sidebar-toggle-below-traffic-lights.md) allows only the explicit sidebar visibility toggle to sit in the lower-left pocket below the traffic lights.

While the window is fullscreen, the Home window chrome disables `.fullSizeContentView` so the `NavigationSplitView` sidebar and split-view backing cannot draw into the native titlebar band. The fullscreen SwiftUI branch avoids ignoring the top safe area, but it also avoids adding extra top padding or painting a separate reserve background.

Normal non-fullscreen windows keep the existing traffic-light-band toolbar alignment and keep using full-size transparent titlebar content.

The fullscreen observer treats SwiftUI helper-view detach as lifecycle cleanup only. It must not clear the fullscreen binding on detach, because fullscreen windows can recompose helper views while remaining fullscreen; only actual fullscreen enter/exit notifications or a live `NSWindow` style-mask read should change the state.

## Consequences

- Moving the pointer to the top of a fullscreen window does not move Routina's layout up or down.
- The visible blank/dead strip above the Home toolbar is not part of the fullscreen design.
- The top-left fullscreen traffic-light area belongs to macOS. Most Routina toolbar controls begin after the reserved leading region, while the explicit sidebar visibility toggle may sit below the traffic lights without overlapping them.
- The Home toolbar, sidebar, and main content remain below the custom toolbar row and do not draw under the native traffic lights.
- The revealed fullscreen traffic lights sit over native titlebar space instead of a rounded sidebar or split-view surface.
- Normal non-fullscreen windows keep full-size transparent titlebar content for the custom Home toolbar alignment.
- Future fullscreen chrome changes must not use pointer polling, revealed-titlebar state, or a separate fullscreen top padding/background to add or remove layout offsets.
- Helper-view detach/reattach does not make fullscreen chrome blink.
