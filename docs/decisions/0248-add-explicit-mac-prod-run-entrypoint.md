# 0248 Add Explicit Mac Prod Run Entrypoint

Status: Accepted

Date: 2026-06-16

Refines: [0238 Use Project-Local Mac Dev Run Entrypoint](0238-use-project-local-mac-dev-run-entrypoint.md)

## Context

The project-local macOS run script made the development loop deterministic, but it only knew how to build and launch `RoutinaMacOSDev`. Contributors still needed to manually locate DerivedData or run Xcode directly when they wanted to launch the production macOS target.

The default Codex Run action should continue to launch the development app because that protects production CloudKit/data surfaces during normal iteration.

## Decision

`script/build_and_run.sh` remains the default macOS development entrypoint, but now accepts an explicit `--prod` flavor that builds and launches the `RoutinaMacOSProd` scheme as `Routinam.app` from a project-local prod DerivedData path.

The script keeps `--dev` as the default flavor, supports the same run/debug/log/telemetry/verify modes for both flavors, and allows `--release` when a release configuration is needed. `.codex/environments/environment.toml` keeps `Run` pointed at the dev path and adds a separate `Run Prod` action for intentional production launches.

## Consequences

- Development launches remain sandboxed by default.
- Production macOS launches no longer depend on manually locating global Xcode DerivedData.
- Agents and contributors can verify prod launch behavior with `./script/build_and_run.sh --prod --verify` or open it with `./script/build_and_run.sh --prod`.
