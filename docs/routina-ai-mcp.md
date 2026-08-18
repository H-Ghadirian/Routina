# Routina AI MCP

Routina's Mac app includes a local read-only MCP bridge. It lets MCP-compatible
AI clients explain Routina features and, with separate opt-in task access,
search tasks, list overdue work, and retrieve a task by UUID. It uses no Routina
backend and never gives the helper direct database access.

## User Setup

1. Open Routina for Mac.
2. Open **Settings > AI Connections**.
3. Click **Copy setup command**, paste it into Terminal, and press Return.
4. Start a new task in ChatGPT or Codex so it discovers the Routina tools.
5. Ask `What is Task Ladder?` or another product question from the in-app guide.
6. To ask about personal tasks, enable **Allow read-only task access** and try
   `What Routina tasks are overdue?`

The copied command uses the full path to the CLI bundled by the installed AI
desktop app when available, so the user does not need a separate `codex` command
on `PATH`. It also uses the MCP helper embedded in the current Routina app bundle.

For a normally installed production build, the equivalent command is:

```bash
'/Applications/Codex.app/Contents/Resources/codex' mcp add routina -- '/Applications/Routinam.app/Contents/Helpers/RoutinaAIMCPServer' --production
```

Some desktop releases bundle the same CLI inside ChatGPT instead. The AI
Connections screen detects that path automatically when it creates the copied
command.

## Data and Privacy Boundary

Local AI Access is off by default. When enabled, the Routina app writes a
versioned JSON snapshot to its private App Group and refreshes it after launch,
activation, and model saves. The snapshot can include task names, schedules,
dates, tags, descriptions, notes, links, goals, places, and progress. Turning the
setting off deletes the snapshot.

Production and development builds use different snapshot filenames. The
`--production` and `--sandbox` helper modes select the corresponding export, so
development data cannot replace production answers.

The MCP helper reads only this snapshot. It does not open SwiftData, migrate the
database, or start CloudKit. The user's AI client may send the task details needed
for an answer to that client's AI provider; Routina does not proxy the request
through its own backend.

## Tools

- `search_routina_help`: Search the bundled product guide by a natural-language
  question or phrase. It does not read the personal task snapshot.
- `get_routina_help_topic`: Retrieve one complete guide topic by the stable ID
  returned from help search. It does not read the personal task snapshot.
- `search_tasks`: Search routines and todos by name, description, notes, tags,
  place, schedule, status, goal, link, or next step.
- `list_overdue_tasks`: Return overdue active tasks.
- `get_task`: Return one task by UUID.

The initial product guide covers Task Ladder, Planner day counts, Availability /
Plan to do / Schedule / Deadline / Reminder, Assumed done, Flags and Tags,
Backlog, Focus, and repeating tasks. Help search remains available when personal
task access is off.

All tools are read-only, non-destructive, and idempotent. Create, update,
complete, archive, and delete tools are intentionally deferred until Routina has
an app-owned approval broker.

## Development

Build the lightweight helper:

```bash
swift build --product RoutinaAIMCPServer
```

Run the protocol smoke test against an empty in-memory catalog:

```bash
.build/arm64-apple-macosx/debug/RoutinaAIMCPServer --in-memory < Tools/RoutinaAIMCPServer/smoke-test.jsonl
```

The Mac Xcode targets build a release helper, copy it to
`Contents/Helpers/RoutinaAIMCPServer`, and sign it before the application bundle
is signed.

For a test fixture, pass `--snapshot-file <path>`. `--sandbox` selects the Routina
development app if the helper needs to launch Routina because a snapshot is
missing; `--production` selects the production app and is the default.

## Claude Desktop

Claude Desktop can use the embedded helper through its MCP configuration:

```json
{
  "mcpServers": {
    "routina": {
      "command": "/Applications/Routinam.app/Contents/Helpers/RoutinaAIMCPServer",
      "args": ["--production"]
    }
  }
}
```

Restart the client after changing its configuration.
