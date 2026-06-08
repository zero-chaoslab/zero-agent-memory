# zero-agent-memory

`zero-agent-memory` is a collection of agent skills for durable task context, reusable memory curation, memory reflection, todo capture, context compaction, and memory-graph visualization.

The project is intended to be public and generic. Keep examples and documentation focused on `zero-context-*` and `zero-memory-*` workflows only.

Declaration: this project is provided only for learning and research purposes and is not intended for commercial use.

## Further Reading

- Blog: [Building Agent Memory from Scratch](https://zero-chaoslab.github.io/posts/building-agent-memory-from-scratch.html)

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

First clone this repository:

```bash
git clone https://github.com/zero-chaoslab/zero-agent-memory.git
cd zero-agent-memory
```

Then run the installer for the agent setup you want:

```bash
bash install.sh {your project path} codex
```

Use `cursor`, `claude`, or `all` instead of `codex` when needed.

The installer appends the generic rules to the target project's `AGENTS.md`, copies skills for the selected agent, and creates Claude hook settings when installing Claude into a project that does not already have `.claude/settings.json`.

### Manual Configuration

Replace `{your project path}` with the target project path. Each agent-specific setup below appends the generic rules to the target project's `AGENTS.md`; review the merged rules if the target project already has an `AGENTS.md`.

#### Codex/Cursor

For Codex, copy all skills into the target project's `.codex/skills` directory:

```bash
cat AGENTS.md >> {your project path}/AGENTS.md
mkdir -p {your project path}/.codex/skills
cp -R skills/* {your project path}/.codex/skills/
```

For Cursor, copy all skills into the target project's `.cursor/skills` directory:

```bash
cat AGENTS.md >> {your project path}/AGENTS.md
mkdir -p {your project path}/.cursor/skills
cp -R skills/* {your project path}/.cursor/skills/
```

After copying, start a new agent session from the target project so the merged rules and copied skills can be discovered.

#### Claude

For Claude, copy all skills into the target project's `.claude/skills` directory:

```bash
cat AGENTS.md >> {your project path}/AGENTS.md
mkdir -p {your project path}/.claude/skills
cp -R skills/* {your project path}/.claude/skills/
```

Then add hook configuration to `{your project path}/.claude/settings.json`. The hooks run the copied Claude skill script from the target project root when Claude receives a prompt or records a task update.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/skills/zero-memory-curator/scripts/print-agents-section.sh --agents-file AGENTS.md \"Zero Context Persistence\""
          },
          {
            "type": "command",
            "command": "bash .claude/skills/zero-memory-curator/scripts/print-agents-section.sh --agents-file AGENTS.md \"Zero Memory Workflow\""
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
            "command": "bash .claude/skills/zero-memory-curator/scripts/print-agents-section.sh --agents-file AGENTS.md \"Zero Context Persistence\""
          }
        ]
      }
    ]
  }
}
```

Keep the section names exactly the same as the `##` headings in the selected `AGENTS.md`.

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

If the earlier `AGENTS.md` rules and hook setup are already configured, `zero-context-persistence`, `zero-context-compact`, and `zero-memory-curator` can be triggered automatically by the agent when appropriate, so users do not need to invoke those skills explicitly in normal usage.

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
