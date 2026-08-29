# 0267 — Use direct links for local destinations in repeated views

Date: 2026-08-29

## Symptom

After opening Timeline from iOS Home, activating a task-backed row first pushed
a black/loading screen, transitioned back, and then showed Task Details with Home
as its Back destination. Changing the row to a namespaced value route then made
the row inert and produced SwiftUI warnings about duplicate and invisible
`navigationDestination` declarations.

## Root Cause

The original Timeline link used a bare `UUID` value on the same compact stack as
Home's different UUID task route, allowing Home to resolve the Timeline link. A
workspace-specific value type removed that semantic collision but still required
Timeline to register a type-wide destination. Routina constructs both the normal
Timeline tab and a Home-embedded Timeline, so SwiftUI encountered repeated route
registrations and did not expose a matching registration from the embedded link's
location.

## Fix

Each task-backed Timeline row now uses a destination-closure `NavigationLink`
that directly constructs Timeline's Task Details destination. The link still
pushes through whichever native stack owns the Timeline presentation, but it no
longer depends on a primitive or namespaced value registration in that shared
environment.

## Prevention Rule

Use a direct destination link when a row owns a local destination and does not
need programmatic path mutation. Reserve value-based navigation for a stack owner
that can register each route type once and expose that registration to every
link. Namespacing prevents semantic collisions, but it does not repair duplicate
or invisible registrations created by repeated embedded views.

## Regression Safeguard

`IOSHomeWorkspaceNavigationSourceTests.homeEmbeddedTimelineUsesDirectTaskDetailLinks`
requires Timeline task rows to construct their destination directly and rejects
both the former bare-UUID link and a registered Timeline route type. The iOS Home
workspace scenario also requires one Task Details push and Back to Timeline.
