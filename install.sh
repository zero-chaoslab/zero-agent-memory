#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash install.sh --project {your project path} --agent codex

Install or update zero-agent-memory rules and skills in a target project.

Agents:
  codex   Copy or update skills in {your project path}/.codex/skills
  cursor  Copy or update skills in {your project path}/.cursor/skills
  claude  Copy or update skills in {your project path}/.claude/skills and add Claude hooks when settings.json is absent
  all     Install or update Codex, Cursor, and Claude skill copies
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project=""
agent="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      project="${2:-}"
      shift 2
      ;;
    --agent)
      agent="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    codex|cursor|claude|all)
      agent="$1"
      shift
      ;;
    *)
      if [[ -z "$project" ]]; then
        project="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 64
      fi
      ;;
  esac
done

if [[ -z "$project" ]]; then
  echo "Missing target project path. Use --project {your project path}." >&2
  usage >&2
  exit 64
fi

case "$agent" in
  codex|cursor|claude|all) ;;
  *)
    echo "Unsupported agent: $agent. Use --agent codex, cursor, claude, or all." >&2
    usage >&2
    exit 64
    ;;
esac

if [[ ! -d "$project" ]]; then
  echo "Target project does not exist: $project" >&2
  exit 66
fi

project_root="$(cd "$project" && pwd)"
agents_file="$project_root/AGENTS.md"
marker_start="<!-- BEGIN zero-agent-memory AGENTS.md -->"
marker_end="<!-- END zero-agent-memory AGENTS.md -->"

install_or_update_agents_rules() {
  if [[ -f "$agents_file" ]] && grep -Fq "$marker_start" "$agents_file"; then
    if ! grep -Fq "$marker_end" "$agents_file"; then
      echo "Found start marker without end marker in: $agents_file" >&2
      echo "Please repair the zero-agent-memory block before running the installer again." >&2
      exit 65
    fi

    local tmp_file
    tmp_file="$(mktemp "${agents_file}.tmp.XXXXXX")"

    if awk -v start="$marker_start" -v end="$marker_end" -v rules_file="$repo_root/AGENTS.md" '
      BEGIN {
        while ((getline line < rules_file) > 0) {
          rules = rules line ORS
        }
        close(rules_file)
        in_block = 0
        replaced = 0
      }
      index($0, start) {
        print start
        printf "%s", rules
        print end
        in_block = 1
        replaced = 1
        next
      }
      in_block {
        if (index($0, end)) {
          in_block = 0
        }
        next
      }
      { print }
      END {
        if (!replaced || in_block) {
          exit 1
        }
      }
    ' "$agents_file" > "$tmp_file"; then
      if ! cp "$tmp_file" "$agents_file"; then
        rm -f "$tmp_file"
        echo "Failed to write updated agent rules to: $agents_file" >&2
        exit 65
      fi
      rm -f "$tmp_file"
      echo "Updated agent rules: $agents_file"
    else
      rm -f "$tmp_file"
      echo "Failed to update managed agent rules block in: $agents_file" >&2
      exit 65
    fi
    return
  fi

  {
    printf '\n%s\n' "$marker_start"
    cat "$repo_root/AGENTS.md"
    printf '%s\n' "$marker_end"
  } >> "$agents_file"
  echo "Installed agent rules: $agents_file"
}

copy_skills() {
  local agent_dir="$1"
  local destination="$project_root/$agent_dir/skills"
  local managed_path
  local skill_path

  mkdir -p "$destination"

  for managed_path in "$destination"/zero-context-* "$destination"/zero-memory-*; do
    if [[ -e "$managed_path" || -L "$managed_path" ]]; then
      rm -rf "$managed_path"
    fi
  done

  for skill_path in "$repo_root"/skills/*; do
    if [[ -d "$skill_path" ]]; then
      cp -R "$skill_path" "$destination/"
    fi
  done

  echo "Updated skills: $destination"
}

install_claude_settings() {
  local settings_dir="$project_root/.claude"
  local settings_file="$settings_dir/settings.json"

  mkdir -p "$settings_dir"
  if [[ -e "$settings_file" ]]; then
    echo "Claude settings already exist: $settings_file"
    echo "Merge hook config manually from: $repo_root/.claude/settings.json"
    return
  fi

  cp "$repo_root/.claude/settings.json" "$settings_file"
  echo "Installed Claude settings: $settings_file"
}

install_or_update_agents_rules

if [[ "$agent" == "codex" || "$agent" == "all" ]]; then
  copy_skills ".codex"
fi

if [[ "$agent" == "cursor" || "$agent" == "all" ]]; then
  copy_skills ".cursor"
fi

if [[ "$agent" == "claude" || "$agent" == "all" ]]; then
  copy_skills ".claude"
  install_claude_settings
fi

echo "zero-agent-memory install complete for: $project_root"
