# 0416: Use Semantic Release Versions

Status: Accepted

## Context

Routina's shipping targets previously used the public version `1` and build number `1`, without a documented rule for future releases. iOS, Watch, macOS, and their bundled extensions must remain version-aligned, while App Store uploads also need monotonically increasing build identifiers.

Date-based versions are readable but do not communicate whether a release contains a fix, a backward-compatible feature, or a major product change. They also become ambiguous when more than one release is prepared on the same day.

## Decision

Use three-component semantic public versions in `MAJOR.MINOR.PATCH` form and a separate monotonically increasing Apple build number:

- Increment `PATCH` for a release containing backward-compatible fixes.
- Increment `MINOR` and reset `PATCH` to zero for a release containing backward-compatible features.
- Increment `MAJOR` and reset `MINOR` and `PATCH` to zero for a major product milestone or compatibility-breaking release.
- Increment `CURRENT_PROJECT_VERSION` for every distributed or uploaded build, including replacement uploads that retain the same public version.

Keep `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` synchronized across the iOS, Watch, macOS, widget, development, and production target configurations. The first release under this convention is public version `1.1.0`, build `2`.

## Consequences

- Users and release notes can distinguish fixes, features, and major releases from the public version.
- App Store uploads remain uniquely ordered by their build number even when the public version does not change.
- Release preparation must update every bundled target together so embedded extensions satisfy Apple's version requirements.
- Calendar dates remain available in release notes and source-control history rather than being encoded into the public version.
