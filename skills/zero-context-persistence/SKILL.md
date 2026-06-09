---
name: zero-context-persistence
description: Persist task context in `.zero-memory/context/<task_slug>/context.md`, and when `context.md` grows beyond 20,000 bytes or 200 lines, use `zero-context-compact` to rewrite it into a restart-safe summary plus durable references before extracting reusable observations into `.zero-memory/daily/` and `zero-memory-curator`.
---

# Zero Context Persistence

Use this skill for non-trivial tasks that may need to survive an agent restart or handoff.

This skill manages restart-safe task state under `.zero-memory/context/` and routes reusable cross-task observations into `.zero-memory/daily/`.

## Script Path Convention

When this skill says to run a bundled helper, resolve it from this skill's own `scripts/` directory instead of hardcoding a workspace-specific skill path. Before executing a shell example, either set `${context_persistence_scripts}` to the resolved `scripts/` directory for the active `zero-context-persistence` skill or substitute that directory directly.

## 1) Determine the active context path first

Before doing substantial work or closing a task that already has saved context, or when the user or workflow explicitly wants one:

1. Determine whether there is an active context path.
2. If the user already provided a path, use it.
3. If the current workflow already established a path, reuse it.
4. If the path is still unknown, run `cat .zero-memory/tmp/current-context.txt`.
5. If `.zero-memory/tmp/current-context.txt` contains a non-empty path, use that as the active context path.
6. If `.zero-memory/tmp/current-context.txt` is empty, use `default` as the context name, resolve it to `.zero-memory/context/default/context.md`, update `.zero-memory/tmp/current-context.txt` to that resolved path, and continue from that context.
7. Only use a different default path such as `.zero-memory/context/<task_slug>/context.md` when the user explicitly asks for a new context or the current workflow explicitly requires one.

Default convention:

- Use the current workspace root, not a nested repo.
- Preferred path for new tasks when a new context is explicitly needed: `.zero-memory/context/<task_slug>/context.md`

Resolution order for the path:

1. user-provided or workflow-provided path
2. `.zero-memory/tmp/current-context.txt`
3. `.zero-memory/context/default/context.md` when `.zero-memory/tmp/current-context.txt` is empty
4. workspace-root task-specific default path such as `.zero-memory/context/<task_slug>/context.md` only when the user explicitly asks for a new context or the workflow explicitly requires one

Do not invent a new location when no path is provided. If the active handoff file is empty, use the workspace-root `default` context. If a new task-specific context is explicitly needed, use the workspace-root default convention unless the user or workflow specifies another location.

When the user explicitly asks to switch to another context name:

1. Resolve the requested name or path to the target `context.md`.
2. Create the file only if it does not exist yet and the switch target needs an initial `context.md`; keep that creation minimal instead of copying or reconciling task notes during the switch itself.
3. Replace the contents of `.zero-memory/tmp/current-context.txt` with that new path before continuing the task.
4. Treat the new path as the active context from that point onward.
5. Do not append switch notes, reconciliation text, or carry-over summaries to either the old context or the new context just because the user asked to switch. Any later write to the new active context should happen only when actual work in that context produces durable information or the user explicitly asks for context maintenance.

## 2) Load or create the task context directory when a path is known

Only do this once the path is known or a new context is explicitly required:

1. Read the existing `context.md` before resuming work.
2. Treat the parent directory as the task context directory, for example `.zero-memory/context/<task_slug>/`.
3. Ensure `context.md` starts with YAML frontmatter containing at least:
   - `name: <task_slug_or_short_task_name>`
   - `description: <one-line summary of the task state>`
4. If the file does not exist yet, create it with that frontmatter plus a concise task summary and resume scaffold.
5. Treat `context.md` as the source-of-truth entrypoint for restart-safe state, not as a dump for raw logs.
6. Keep path references inside `context.md` repo-local whenever possible; prefer `./`, `.zero-memory/context/...`, and other relative paths over the current absolute repo or worktree path.
7. Do not add `Active repo: /abs/path`-style notes unless the user explicitly asks for that exact path or the task itself is about a path-specific environment issue.
8. Create sibling directories only when needed:
   - `references/` for deeper task details that should remain durable but should not clutter `context.md`
   - `scripts/` for useful task-local helpers that support the current task

Example header:

```markdown
---
name: issue-7731-timeout-fix
description: Investigate timeout overflow behavior, implement the accepted fix path, and track remaining verification.
---
```

## 3) Keep `context.md` concise and reference deeper material

Use `context.md` for the compact summary a restarted agent should read first:

- task goal and status
- current understanding
- important decisions and rationale
- assumptions that still need verification
- touched files, symbols, or systems
- verification already completed and verification still pending
- blockers, open questions, and the next recommended step

Correlation rule:

- Only record work that actually belongs to the active context.
- If the current task, or a subtask discovered during the task, is not meaningfully correlated to the active context, do not write that unrelated progress, analysis, or status into the current `context.md`.
- If the unrelated work still needs restart-safe tracking, use a separate context only when the user explicitly asks for that context or the workflow explicitly requires creating or switching to one.
- If no separate context is created, keep the unrelated work out of the current context rather than mixing two task histories together.

Path-writing rule:

- Prefer repo-local references in `context.md` so the same task remains valid across different git worktree locations.
- Avoid absolute repo/worktree paths in normal task notes because they become stale when the same repository is resumed from another checkout path.
- If an absolute path is itself part of the bug, environment setup, or reproduction, keep it narrowly scoped and explain why that path matters.
- When a task workflow deliberately changes the active context, keep `.zero-memory/tmp/current-context.txt` in sync with the selected `context.md` path.

When `context.md` becomes too large or the user asks to summarize it:

1. If the active `context.md` is over `20,000` bytes or over `200` lines, route the rewrite through `zero-context-compact` instead of manually trimming it.
2. Split the detailed material into multiple files under `.zero-memory/context/<task_slug>/references/`.
3. Keep the new `context.md` short and current instead of deleting the older detail.
4. Add a `## References` section in `context.md` that lists each reference file with a short description of what it contains.
5. If the detail came from an older, larger `context.md`, say that clearly in the reference descriptions so a restarted agent knows those files preserve the original detail.
6. After compaction, compare the rewritten summary with the preserved references. If the rewrite moved or compressed reusable knowledge that would now be easier to miss, including corrections, workflow rules, debugging methods, code-structure or call-path analysis, behavior notes, design decisions, or other durable technical insight, append a daily-learning entry and hand its ID to `zero-memory-curator` in the same turn.
7. Keep `context.md` under `20,000` bytes and `200` lines. Use `python3 "${context_persistence_scripts}/compact_context.py" --max-bytes 20000 --max-lines 200` when a deterministic rewrite into classified `references/` files is needed.

Example reference descriptions:

- `references/original-context-analysis.md` - Detailed analysis split out from the original full `context.md` during summarization.
- `references/debugging-notes.md` - Curated reproduction notes, command findings, and investigation details that are too detailed for the summary.

## 4) What belongs in `references/`

Use `references/` for durable task-local detail such as:

- expanded code exploration or call-path analysis
- root-cause notes and debugging chronology
- curated command findings and reproduction steps
- design sketches or alternative options that are still useful to preserve
- sections split out from an older `context.md` during summarization

Do not move disposable raw logs into `references/`. Temporary logs, build logs, and similar scratch output still belong under workspace-root `.zero-memory/tmp/`.
When an active context path exists, put task scratch output under `.zero-memory/tmp/<context_name>/...`, where `<context_name>` is the active context directory name.

## 5) What belongs in `scripts/`

Use `.zero-memory/context/<task_slug>/scripts/` for useful task-local helpers such as:

- repeatable repro commands wrapped in a script
- parsing or extraction helpers for task-specific artifacts
- verification helpers that make task resumption faster

When a script is important for continuation, mention it in `context.md` with:

- the relative path
- what it does
- the key inputs or assumptions
- whether it has already been run and what it produced

If a script becomes broadly reusable across tasks, consider promoting it into a project skill or a shared script location instead of keeping it task-local forever.

Use `zero-context-compact` when the task needs a deterministic compaction pass that snapshots the old `context.md`, rewrites a concise summary, and splits durable detail into named `references/` files. The underlying rewrite command is `python3 "${context_persistence_scripts}/compact_context.py" --max-bytes 20000 --max-lines 200`.

## 6) Design-analysis workflows

When the task includes design authoring, use the same task context directory as the analysis foundation for the design.

Typical design-analysis content includes:

- codebase exploration: existing implementation patterns, key data structures, relevant subsystems
- call-path analysis: important function call chains, entry points, and flow diagrams with file paths and line numbers
- current behavior: how the code works today, including edge cases and platform differences
- root-cause analysis: for bug fixes, what actually causes the problem and why
- architecture observations: why the existing code is structured the way it is

For design-heavy tasks:

- do the summary in the active task context before writing the design doc
- keep deeper analysis in `context.md` or split it into `references/` when the detail becomes too large
- keep updating the same task context directory during design authoring, implementation, and debugging
- include concrete file paths, line numbers, code snippets, tables, or diagrams when they materially improve clarity
- keep the context focused on analysis and discovery rather than duplicating the design document
- let the design document reference the task context instead of repeating the full analysis

Useful sections for these tasks often include:

- complete function call chains with callers
- key data structures and relationships
- entry point inventory
- platform-specific behavior differences
- corrections to earlier assumptions
- important code patterns or macros used by related code

## 7) How to write corrections

When new investigation disproves an earlier assumption:

- do not leave the old statement unqualified
- add an explicit correction such as "Correction: earlier context assumed X, but actual behavior is Y because..."
- update the current-state sections so a restarted agent does not follow stale guidance
- if the corrected detail lives in `references/`, update the `## References` description or add a note that the file is superseded

Preserve useful history, but make the latest understanding obvious.

## 8) Daily-learning extraction and handoff

When the skill logs a reusable new item into `context.md`, or reconciles `context.md` on completion, it should decide whether the new information belongs beyond the current task.

After useful work or problem-solving, explicitly evaluate whether extractable knowledge emerged. Strong signals include:

- a non-obvious solution discovered through investigation
- a workaround for unexpected behavior
- a project-specific pattern learned
- an error that required debugging to resolve

Treat these questions as prompts that help you notice reusable knowledge early; they do not replace the reuse rules below.

Extract when the item is:

- a verified workflow rule
- a correction to an earlier wrong assumption
- a reusable debugging or validation method
- a durable code-structure, call-path, or behavior analysis that would save future investigation work
- a durable design decision with rationale
- a feature-gap or tooling-gap discovery
- a recurring failure-prevention rule

Do not extract:

- raw command logs
- transient status updates
- task-only negotiation text
- unverified speculation

If the item is reusable:

1. Append it to `.zero-memory/daily/learning.YYYY-MM-DD.md`.
2. Give it a globally unique ID in the format `DL-YYYYMMDD-HHMMSS.mmmZ-<random-suffix>`.
3. Preserve provenance back to the source task context and source sections.
4. When the new item corrects older learning or curated memory, add lightweight lifecycle metadata such as `Supersedes Daily Learning IDs` or `Supersedes Memory IDs` when the corrected targets are known.
5. Pass the new daily-learning entry ID to `zero-memory-curator` directly instead of routing through `self-improving-agent`.

Compaction-specific reminder:

- When `zero-context-compact` rewrites `context.md`, treat the preserved `references/` files and the shorter replacement summary as a recall-risk review.
- If reusable information would now be easier to miss because it mostly lives in archived references or was compressed into a short summary bullet, promote that item through daily learning and `zero-memory-curator` before closing the task, including reusable code-structure analysis, behavior notes, and other durable technical insight rather than only workflow or debugging rules.
- If the rewrite only moved task-local history with no reusable rule, correction, or method, do not create memory noise just because compaction happened.

Recommended entry shape:

```markdown
## DL-20260401-173000.123Z-a1b2c3d4
- Timestamp: 2026-04-01T17:30:00Z
- Source Slug: zero-memory-management-design
- Source Context: .zero-memory/context/zero-memory-management-design/context.md
- Type: best-practice
- Pattern-Key: workflow.zero-context-persistence-and-reconciliation
- Summary: Task context reconciliation should emit reusable learning directly into `.zero-memory/daily/`.
- Details: ...
- Why Reusable: ...
- Suggested Memory Targets:
  - workflow.task.context.persistence
- Related Files:
  - skills/zero-context-persistence/SKILL.md
- Source Sections:
  - Decisions
  - Completion Notes
- Status: new
```

Optional correction metadata:

- `Supersedes Daily Learning IDs`
  - Add when the new learning explicitly corrects or replaces an older `DL-*` entry.
- `Supersedes Memory IDs`
  - Add when the new learning materially invalidates or replaces an existing curated memory.
- `Related Symbols`
  - Add when a stable symbol name makes later lookup cheaper than file-path matching alone.

When the corrected target is not yet known:

- do not guess `Supersedes Daily Learning IDs` or `Supersedes Memory IDs`
- do record the best lookup keys you already know, especially `Pattern-Key`, `Related Files`, and `Related Symbols`
- let `zero-memory-curator` shortlist the likely older memories through exact-key and index-based lookup before deciding whether the new entry confirms, refines, or replaces prior memory

Daily learning remains the append-first evidence log, but later curation may update lightweight lifecycle metadata such as `Status` or supersession links when cross-references become known.

## 9) Completion workflow

Before final handoff, if an active context path is in use:

1. Re-read the current `context.md`.
2. Reconcile it with what was actually learned during the task.
3. Append durable findings that matter for continuation or later follow-up.
4. Correct misunderstandings that are still visible in the file.
5. Remove or rewrite stale worktree-specific absolute repo paths unless the task explicitly depends on those exact paths.
6. Drop or move aside notes that turned out to belong to an unrelated task thread instead of leaving them mixed into the current context history.
7. Explicitly evaluate whether useful work or problem-solving produced extractable knowledge using the Section 8 checklist, then extract reusable findings into `.zero-memory/daily/` when they meet the daily-learning criteria.
8. Ensure `## References` still points to the right supporting files and descriptions.
9. Mark the task status clearly, including any remaining follow-up items.

If no active context path exists because the user explicitly asked not to use context persistence for this task, do not create a new `context.md` just for closeout. An empty `.zero-memory/tmp/current-context.txt` is different: resolve and use the workspace-root `default` context.

The completion state should let a restarted agent answer:

- What was the goal?
- What is now known to be true?
- What changed?
- What is still pending?
- Where should work resume?
- Which reference files or task-local scripts matter next?

## 10) Resume behavior

When resuming a saved task:

1. Read `context.md` first.
2. Use it to reconstruct goal, status, pending work, and which reference files matter.
3. Read only the referenced detail files that are relevant to the next step.
4. Verify any time-sensitive assumptions against the code or environment before acting on them.
5. Continue updating the same task context directory as the task evolves.

## 11) Suggested template

Use the template in [reference.md](reference.md) when you need a starting structure or a compact summary layout.

## 12) Shared context-description helper

Use `scripts/load_context_descriptions.py` when you need a lightweight summary of saved task contexts without opening each file manually.

- It accepts bare context names, context directories, or explicit `context.md` paths.
- Pass multiple targets to load several contexts at once.
- Pass `--all` to scan every `.zero-memory/context/*/context.md` entry under the chosen root.
- If no targets are provided, it falls back to `.zero-memory/tmp/current-context.txt` when that file contains a path.
