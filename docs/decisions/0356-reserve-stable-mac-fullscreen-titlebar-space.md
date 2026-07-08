# 0356: Reserve Stable Mac Fullscreen Titlebar Space

Date: 2026-07-09

Status: Accepted

Supersedes: [0355 Integrate Mac Fullscreen Traffic Lights Into Home Toolbar](superseded/0355-integrate-mac-fullscreen-traffic-lights-into-home-toolbar.md)

Refines: [0022 Own Mac Home Toolbar at the Split Shell](0022-own-mac-home-toolbar-at-split-shell.md), [0341 Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

Mac Home draws its own SwiftUI toolbar and uses a full-size transparent titlebar. Decision 0355 kept the toolbar in the titlebar band and relied on leading traffic-light padding. Visual verification showed that this still lets the top-left Home shell appear behind the native fullscreen traffic lights.

The earlier pointer-driven reserve from decision 0354 avoided some overlap, but it changed layout while the pointer moved to or away from the top edge. That made the whole app jump.

## Decision

Mac Home observes only whether its window is fullscreen.

When Home is fullscreen, it reserves a stable native-titlebar-height area above the SwiftUI toolbar for the whole fullscreen session. The reserve is not tied to pointer location or to whether macOS has currently revealed the fullscreen titlebar strip.

Normal non-fullscreen windows keep the existing traffic-light-band toolbar alignment. Fullscreen windows keep the toolbar, sidebar, and main content below the native traffic-light/titlebar area.

The fullscreen observer treats SwiftUI helper-view detach as a lifecycle cleanup only. It must not clear the fullscreen binding on detach, because fullscreen windows can recompose helper views while remaining fullscreen; only actual fullscreen enter/exit notifications or a live `NSWindow` style-mask read should change the state.

## Consequences

- Moving the pointer to the top of a fullscreen window does not move Routina's layout up or down.
- The Home toolbar, sidebar, and main content do not draw underneath the native fullscreen traffic lights.
- Fullscreen keeps a stable top titlebar area even while macOS hides its transient titlebar chrome.
- Future fullscreen chrome changes must not use pointer polling or revealed-titlebar state to add/remove layout offsets.
- Helper-view detach/reattach does not make the fullscreen titlebar reserve blink.
