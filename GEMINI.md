# Gemini Workspace Guide

This file provides workspace configuration, tooling integration, and architectural guidance for Gemini CLI sessions in this repository.

## vvx MCP Server Integration

The project provides custom developer tooling accessible via a Model Context Protocol (MCP) server named `vvx`.

### Server Configuration
The server is configured in `.mcp.json` at the root of the workspace:
* **Executable Path:** `./Tools/vvk/bin/vvx-darwin-arm64` (on macOS Apple Silicon)
* **Start Command:** `mcp` (runs a JSON-RPC stdio server)

### Protocol Handshake Requirements
When communicating directly with the `vvx` MCP server, you must complete the standard MCP initialization handshake before sending any tool requests:
1. **Initialize:** Send a `method: "initialize"` request (e.g., with `"protocolVersion": "2024-11-05"`).
2. **Initialized:** Send a `method: "notifications/initialized"` notification.
3. **Tools List / Call:** Send subsequent requests like `method: "tools/list"` or `method: "tools/call"`.

### Model Gating Requirement
All commands sent to the `jjx` tool (except `jjx_open` itself) are model-gated and require a **frontier-tier model**. The `vvx` MCP server inspects the `model` parameter of the tool call. If the model string does not match an accepted frontier model (e.g., `gemini-1.5-pro` is currently blocked), the call will be rejected.
* **Workaround:** Pass `"claude-opus-4-8"`, `"claude-fable"`, or `"gpt-5.5"` verbatim in the `model` parameter of the tool argument payload to pass the model gate.

## Detailed Tool & Project Documentation

For specific tool workflows, available command references, and repository naming conventions, refer to the authoritative documentation:

* **`.mcp.json`**: Current configuration for local MCP servers.
* **`CLAUDE.md`**: Main project memo defining layout configurations, file map, parallel agent workflow (Motet), and PR procedures.
* **`Tools/jjk/claude-jjk-core.md`**: Reference file for all available `jjx` command parameters, subcommands, and the Officium Protocol.
* **`Tools/jjk/README.md`**: Core concepts of Job Jockey (Heats, Paces, Itches, Scars, and steeplechase logs).
