# 0160: Support Mac Browser Website Blocking

## Status

Accepted

## Date

2026-06-05

## Context

Routina previously treated typed website blocking as enforceable on iOS only. Mac website blocking was deferred because the existing Mac blocker only closes selected apps, and the iOS Screen Time token APIs are unavailable to macOS apps.

Other Mac focus apps can still block entered websites by using browser-specific mechanisms such as Apple Events automation or browser extensions. This is not the same as system-wide network filtering, but it provides useful friction in common browsers.

## Decision

Routina supports best-effort Mac website blocking for entered domains by automating supported browsers while an enabled protected mode is active. When the frontmost Safari or common Chromium browser tab matches an entered domain, Routina redirects that tab to `about:blank`.

The macOS app declares Apple Events automation permission and explains that browser control is used only while website blocking is active. Users may need to approve control of each browser in macOS privacy prompts.

This is intentionally browser-based blocking, not system-wide network filtering. Unsupported browsers, including Firefox, require a future browser extension or content-filter path.

## Consequences

- Mac users can enter website domains in Blocking settings and get immediate browser-level blocking for Safari and common Chromium browsers.
- The same Focus, Away, and Sleep applicability model applies to Mac website domains.
- Blocking is best-effort: denied automation permission, unsupported browsers, private browser behavior, or browser scripting changes can prevent enforcement.
- A future Network Extension or browser extension could supersede this path if Routina needs stronger system-wide coverage.
