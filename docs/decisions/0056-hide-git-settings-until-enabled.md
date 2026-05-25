# 0056 Hide Git Settings Until Enabled

- **Status:** Accepted
- **Date:** 2026-05-25

## Context

GitHub and GitLab contribution integrations are optional app features. Keeping a standalone Git settings destination visible while Git features are disabled makes the main settings list feel noisier and splits the enablement control away from the broader app behavior settings.

## Decision

Expose the Git feature toggle in Settings > General > Advanced. Hide the standalone Git settings section from Settings navigation while Git features are disabled. When the toggle is enabled, show the Git section so users can configure GitHub and GitLab connections.

## Consequences

- General owns opt-in access to advanced optional integrations.
- The Git settings detail no longer includes its own feature enablement section.
- Settings navigation must fall back to a visible section if persisted state still points at Git after the feature has been disabled.
