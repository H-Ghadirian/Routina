# Routina AI MCP

This is the local read-only MCP bridge for Routina. It lets MCP clients ask for task data through tools without embedding a chat UI inside the app.

## Build

```bash
swift build --product RoutinaAIMCPServer
```

## Smoke Test

This runs the server against an empty in-memory store and exercises initialize, tool discovery, and one tool call.

```bash
.build/arm64-apple-macosx/debug/RoutinaAIMCPServer --in-memory < Tools/RoutinaAIMCPServer/smoke-test.jsonl
```

The response should include the `search_tasks`, `list_overdue_tasks`, and `get_task` tools.

## Claude Desktop

Anthropic currently recommends Desktop Extensions for polished local MCP installs, but local development can still use a JSON config style like their documented examples for Claude Desktop MCP servers.

Add this server under the `mcpServers` key in Claude Desktop's MCP config:

```json
{
  "mcpServers": {
    "routina": {
      "command": "/Users/ghadirianh/Routina/.build/arm64-apple-macosx/debug/RoutinaAIMCPServer",
      "args": []
    }
  }
}
```

For production data instead of the default app environment, pass:

```json
{
  "mcpServers": {
    "routina": {
      "command": "/Users/ghadirianh/Routina/.build/arm64-apple-macosx/debug/RoutinaAIMCPServer",
      "args": ["--production"]
    }
  }
}
```

Restart Claude Desktop after changing the config. In Claude Desktop, check the connected tools list and ask something like:

```text
What Routina tasks are overdue?
```

## Tools

- `search_tasks`: Search routines and todos by name, notes, tags, place, schedule, status, or next step.
- `list_overdue_tasks`: Return overdue active tasks.
- `get_task`: Return one task by UUID.

All current tools are read-only. They include MCP annotations with `readOnlyHint: true`, `destructiveHint: false`, `idempotentHint: true`, and `openWorldHint: false`.

## Notes

- The server opens a local-only SwiftData container, so it does not start CloudKit sync work itself.
- The app's existing iCloud sync can keep the local store fresh before the MCP client reads it.
- Write tools should be added later with explicit confirmation in the host client or a Routina-side approval flow.
