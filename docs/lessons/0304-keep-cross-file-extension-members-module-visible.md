# 0304 — Keep cross-file extension members module-visible

Date: 2026-09-05

## Symptom

A fresh Xcode build failed after the unified recurrence editor was split into
multiple files because its binding extension could not access the fixed-start
date-picker configuration.

## Root Cause

`fixedStartComponents` retained `private` access while one of its callers moved
to an extension in another source file. Swift's file-scoped `private` boundary
made the otherwise unchanged call invalid.

## Fix

The shared member now uses the default module visibility required by the
cross-file editor extension.

## Prevention Rule

When extracting a type's extensions into separate files, audit every referenced
member whose access is `private` or `fileprivate` and widen only the members
that cross the new file boundary.

## Regression Safeguard

Strict Swift formatting and lint run on both editor files, and the shared tests
plus fresh macOS and iOS development builds compile the split extensions
together.
