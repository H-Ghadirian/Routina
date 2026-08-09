# 0517 Sandbox the Embedded MCP Helper

Status: Accepted

Date: 2026-08-09

## Context

Routina embeds its read-only MCP server as a Swift Package executable inside the macOS app bundle. The app target has App Sandbox enabled, but the build script previously re-signed the embedded helper without any entitlements. App Store Connect rejects a macOS archive when an embedded executable is not sandboxed.

## Decision

The embedded `RoutinaAIMCPServer` is signed from `script/embed_mcp_helper.sh` with the dedicated `Config/macOS/RoutinaAIMCPServer.entitlements` file. That file contains exactly `com.apple.security.app-sandbox` and `com.apple.security.inherit`, both set to true. The build script also assigns the helper a bundle-scoped code-signing identifier and preserves hardened runtime signing.

## Consequences

- App Store Connect accepts the helper as an embedded executable in a sandboxed macOS app.
- The helper inherits the containing Routina app's sandbox rather than requesting separate capabilities.
- Adding any further App Sandbox entitlement to this helper requires a deliberate review because it would invalidate the inheritance contract.
