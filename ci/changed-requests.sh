#!/usr/bin/env bash
# Prints a JSON array of subscription request files for the pipeline matrix.
#
#   ci/changed-requests.sh all            every request (drift, manual full run)
#   ci/changed-requests.sh <base> <head>  requests added or modified between two commits;
#                                         every request if shared code changed
#                                         (modules/, stacks/, config/)
#
# Deleted request files are never returned: removing a file does not destroy anything.
# Decommissioning is the separate vending-destroy workflow.
set -euo pipefail

all_requests() {
  git ls-files 'subscriptions/*.yaml'
}

if [ "${1:-}" = "all" ]; then
  FILES=$(all_requests)
else
  BASE="${1:?base commit}"
  HEAD="${2:?head commit}"
  # First push to a branch: no "before" commit.
  if [ "$BASE" = "0000000000000000000000000000000000000000" ]; then
    BASE="$(git rev-parse "$HEAD~1")"
  fi
  if git diff --name-only "$BASE...$HEAD" | grep -qE '^(modules|stacks|config)/'; then
    FILES=$(all_requests)
  else
    FILES=$(git diff --name-only --diff-filter=AM "$BASE...$HEAD" -- 'subscriptions/*.yaml')
  fi
fi

printf '%s\n' "$FILES" | jq -R -s -c 'split("\n") | map(select(length > 0))'
