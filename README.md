# zero-agent-memory

`zero-agent-memory` is a collection of agent skills for durable task context, reusable memory curation, memory reflection, todo capture, context compaction, and memory-graph visualization.

The project is intended to be public and generic. Keep examples and documentation focused on `zero-context-*` and `zero-memory-*` workflows only.

Declaration: this project is provided only for learning and research purposes and is not intended for commercial use.

## Requirements

Required for normal skill usage:

- Python `>= 3.11.7`
- A POSIX-like shell environment for shell helpers
- Git, when installing or using the project as a repository or submodule

Required only when rebuilding the web UI assets for `zero-memory-visual`:

- Node.js, validated with `>= 25.6.0`
- npm, validated with `>= 11.8.0`
- TypeScript compiler through `npx --package typescript`

Normal dashboard generation does not require TypeScript tooling because the compiled browser snapshot is checked in.

## Quick Start

Add `zero-agent-memory` to your project as a skill collection, then merge the relevant rules from this repository's `AGENTS.md` into your own project's agent rules.

When using Cursor or Codex, make sure those merged rules are loaded by the agent before asking it to use `zero-context-*` or `zero-memory-*` skills. The rules describe how to persist task context, curate reusable memory, keep temporary data isolated, and avoid leaking project-specific examples into this public skill collection.

## Agent Rule Hooks

Some agents can run command hooks that inject project rules when a prompt starts or a task state changes. The helper `scripts/print-agents-section.sh` prints one named `##` section from an `AGENTS.md` file so a project can load large rule files as smaller, ordered hook outputs.

Example:

```bash
bash path/to/zero-agent-memory/scripts/print-agents-section.sh \
  --agents-file path/to/your/project/AGENTS.md \
  "Zero Context Persistence"
```

Use `--agents-file` when the hook must load a specific workspace's rules. If it is omitted, the helper searches upward from the current directory for `AGENTS.md` and then falls back to the `AGENTS.md` in this repository.

Claude settings example:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash path/to/zero-agent-memory/scripts/print-agents-section.sh --agents-file path/to/your/project/AGENTS.md \"Zero Context Persistence\""
          },
          {
            "type": "command",
            "command": "bash path/to/zero-agent-memory/scripts/print-agents-section.sh --agents-file path/to/your/project/AGENTS.md \"Zero-Memory Workflow\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "TaskUpdate",
        "hooks": [
          {
            "type": "command",
            "command": "bash path/to/zero-agent-memory/scripts/print-agents-section.sh --agents-file path/to/your/project/AGENTS.md \"Zero Context Persistence\""
          }
        ]
      }
    ]
  }
}
```

Add one command hook per section that should be loaded. Keep the section names exactly the same as the `##` headings in the selected `AGENTS.md`.

## Skills

- `zero-context-persistence`: persist restart-safe task context under `.zero-memory/context/`.
- `zero-context-compact`: compact oversized context into summary plus durable references.
- `zero-context-todo-list`: keep user-controlled todo lists in the active context.
- `zero-memory-curator`: promote reusable daily learning into graph-backed memory packages.
- `zero-memory-reflection`: analyze missed recall and approved memory-graph refactor plans.
- `zero-memory-visual`: generate or serve the `ZeroAgentMemory` web dashboard.

## Usage

Use these skills through an agent that can load skill instructions. For example, ask the agent to use:

- `zero-context-persistence` when task context should survive restarts.
- `zero-context-compact` when an active context grows too large.
- `zero-memory-curator` when reusable learning should be promoted into memory.
- `zero-memory-visual` when you want the agent to show the `ZeroAgentMemory` web dashboard.

The agent should run the underlying scripts and choose safe output locations for the current workspace. Users normally should not need to run the dashboard script by hand.

## Data Layout

The skills expect memory data under a workspace-local `.zero-memory/` directory:

- `.zero-memory/context/`: task context files and references.
- `.zero-memory/daily/`: append-only daily learning entries.
- `.zero-memory/memory/`: curated memory packages and generated indexes.
- `.zero-memory/observability/`: recall and reflection event journals plus reports.
- `.zero-memory/skills/`: workspace-local skill links, overrides, or project-specific skill adapters.
- `.zero-memory/tmp/`: disposable scratch output.

## Public Boundary

Do not add private project names, organization names, hostnames, local machine paths, issue IDs, or internal workflow examples to this repository.

When examples are needed, use neutral memory/context scenarios such as debugging a generic service, preserving a design decision, or compacting an oversized task context.
