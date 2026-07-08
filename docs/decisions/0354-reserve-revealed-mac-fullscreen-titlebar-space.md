# 0354: Reserve Revealed Mac Fullscreen Titlebar Space

Date: 2026-07-08

Status: Accepted

Refines: [0352 Respect Mac Home Fullscreen Titlebar Safe Area](0352-respect-mac-home-fullscreen-titlebar-safe-area.md), [0341 Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

Mac Home draws its own SwiftUI toolbar in the titlebar-height band. Decision 0352 made fullscreen Home stop ignoring the top safe area, but visual verification showed that macOS can still reveal a transient native fullscreen titlebar strip over a full-size-content SwiftUI window. Hiding the native toolbar background or hiding the standard traffic-light buttons did not remove that revealed strip.

Always reserving the strip height in fullscreen avoids coverage, but leaves a permanent blank band while fullscreen system chrome is hidden.

## Decision

Mac Home keeps the normal fullscreen toolbar alignment while the macOS fullscreen titlebar is hidden.

While the pointer is at the top edge and macOS reveals the menu/titlebar controls, Home reserves the revealed titlebar height above its SwiftUI toolbar. After the pointer leaves the top edge and the native titlebar has time to hide, Home removes that extra reserve.

The fullscreen state and revealed-titlebar state are tracked separately through the AppKit window bridge. Normal windows continue to ignore the top safe area so the custom toolbar stays aligned with the traffic-light titlebar band.

## Consequences

- The revealed macOS fullscreen titlebar no longer covers Routina's search, sidebar, mode, or action controls.
- Hidden fullscreen chrome does not leave a permanent blank strip above the Home toolbar.
- Future Mac Home chrome changes should distinguish "window is fullscreen" from "fullscreen titlebar is currently revealed."
