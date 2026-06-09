#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash install.sh --project {your project path} --agent codex

Install zero-agent-memory rules and skills into a target project.

Agents:
  codex   Copy skills to {your project path}/.codex/skills
  cursor  Copy skills to {your project path}/.cursor/skills
  claude  Copy skills to {your project path}/.claude/skills and add Claude hooks when settings.json is absent
  all     Install Codex, Cursor, and Claude skill copies
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

append_agents_rules() {
  if [[ -f "$agents_file" ]] && grep -Fq "$marker_start" "$agents_file"; then
    echo "Agent rules already installed: $agents_file"
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
  mkdir -p "$destination"
  cp -R "$repo_root/skills/." "$destination/"
  echo "Installed skills: $destination"
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

append_agents_rules

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
