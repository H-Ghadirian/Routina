# Use an App-Owned iOS More Tab

- Status: Accepted
- Date: 2026-05-13

## Context

On compact iPhone layouts, SwiftUI/UITabBarController moves overflow tabs into a system-provided More navigation controller. Settings also needs its own section navigation. Placing Settings inside the system More stack creates nested navigation hierarchies, which can show competing back controls or require fragile UIKit navigation-bar manipulation.

## Decision

The compact iOS app uses an app-owned More tab instead of relying on UIKit's automatic overflow More tab for Stats and Settings. The More tab owns a single SwiftUI navigation stack with destinations for Stats, Settings, and Settings sections. Settings can still own its own compact navigation stack when presented directly outside the More flow.

## Consequences

- Compact iOS navigation for More -> Settings -> section has exactly one active navigation hierarchy.
- The app avoids post-navigation UIKit toolbar hiding or other timing-sensitive layout fixes.
- Stats and Settings remain direct tabs on regular-width iOS layouts and macOS.
- The shared `Tab.more` value represents the app-owned compact More tab.
