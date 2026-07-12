#!/bin/zsh

set -euo pipefail

usage() {
  print -- "Usage: ${0:t} [--dry-run] [history-file]"
}

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi

if (( $# > 1 )); then
  usage >&2
  exit 64
fi

history_file="${1:-${HISTFILE:-$HOME/.zsh_history}}"
if [[ ! -r "$history_file" ]]; then
  print -u2 -- "History file is not readable: $history_file"
  exit 66
fi

if (( ! dry_run )) && ! command -v zoxide >/dev/null 2>&1; then
  print -u2 -- "zoxide is not installed or not available in PATH."
  exit 69
fi

typeset -A unique_paths
integer imported=0

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"

  # Zsh extended history stores entries as ': <epoch>:<duration>;<command>'.
  if [[ "$line" == ': '<->':'<->';'* ]]; then
    line="${line#*;}"
  fi

  # ${(z)} performs shell lexical splitting without executing the command.
  tokens=("${(@z)line}")
  (( ${#tokens} >= 2 )) || continue
  [[ "${(Q)tokens[1]}" == "cd" ]] || continue

  integer path_index=2
  if [[ "${(Q)tokens[2]}" == "--" ]]; then
    path_index=3
  fi
  (( ${#tokens} == path_index )) || continue

  candidate="${(Q)tokens[$path_index]}"

  # History has no cwd per entry, so relative paths cannot be reconstructed.
  # Reject expansion syntax as data; never eval history content.
  [[ "$candidate" != *'$'* && "$candidate" != *'`'* ]] || continue
  if [[ "$candidate" == "~" ]]; then
    candidate="$HOME"
  elif [[ "$candidate" == '~/'* ]]; then
    candidate="$HOME/${candidate#\~/}"
  elif [[ "$candidate" != /* ]]; then
    continue
  fi

  [[ -d "$candidate" ]] || continue
  candidate="${candidate:A}"

  if (( dry_run )); then
    print -r -- "$candidate"
  else
    zoxide add "$candidate"
  fi

  (( imported += 1 ))
  unique_paths[$candidate]=1
done < "$history_file"

print -- "Imported $imported history entries (${#unique_paths} unique directories)."
