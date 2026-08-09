# 0520: Archive Embedded Helper dSYM Files

Status: Accepted

Date: 2026-08-09

## Context

`RoutinaAIMCPServer` is built by Swift Package Manager and copied into the macOS app by a shell-script build phase. Unlike an Xcode target, that helper's symbols are not automatically collected in a macOS archive.

App Store Connect reported the helper's UUID without a corresponding dSYM, which prevented symbolication for crashes in the helper process.

## Decision

When the macOS target requests `dwarf-with-dsym`, the helper embedding phase invokes `dsymutil` on the exact embedded `RoutinaAIMCPServer` executable and writes `RoutinaAIMCPServer.dSYM` to `DWARF_DSYM_FOLDER_PATH`.

Do not create a dSYM for configurations that do not request one. Xcode then collects the helper's companion dSYM with the archive alongside the app and package symbols.

## Consequences

- App Store Connect receives symbols matching the externally built helper UUID.
- Helper crash reports retain source-level symbolication.
- The archive remains the source of truth for symbols, without shipping a dSYM inside the app bundle.
