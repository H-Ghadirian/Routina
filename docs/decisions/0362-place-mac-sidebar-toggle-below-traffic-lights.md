# 0362: Place Mac Sidebar Toggle Below Traffic Lights

Date: 2026-07-10

Status: Accepted

Refines: [0343 Add Mac Home Sidebar Collapse Control](0343-add-mac-home-sidebar-collapse-control.md), [0357 Integrate Mac Fullscreen Titlebar Reserve Into Toolbar](0357-integrate-mac-fullscreen-titlebar-reserve-into-toolbar.md)

## Context

Decision 0357 kept the leading native traffic-light area empty so fullscreen Home could avoid drawing controls under the macOS window buttons. With the consolidated toolbar row, that left an unused lower-left pocket below the traffic lights while the explicit sidebar toggle sat farther right than the sidebar edge it controls.

The lower-left pocket has enough vertical space for the existing 28 pt sidebar toggle target without overlapping the traffic lights.

## Decision

Mac Home positions the explicit sidebar visibility toggle in the lower-left titlebar pocket below the native traffic lights. The toggle remains in the root-owned SwiftUI top toolbar chrome, keeps its fixed 28 pt target and full-surface hit shape, and continues driving the shared `NavigationSplitView` column visibility.

The broader Home toolbar controls still begin after the traffic-light-safe leading reserve so status badges, search, mode navigation, Places, Progress, and board inspector controls do not compete with native window controls. The sidebar toggle is the only Routina control allowed inside that leading reserve, and it must stay visually below, not on top of, the traffic lights.

## Consequences

- The sidebar collapse/restore affordance sits closer to the sidebar it controls.
- Fullscreen still avoids a separate blank titlebar band and still keeps native traffic lights clear.
- Search centering and trailing toolbar command layout remain independent of the sidebar toggle placement.
- Future toolbar changes should not move additional controls into the traffic-light reserve unless they introduce a new decision.
