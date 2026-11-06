#!/bin/sh
# Fails if a plan deletes or replaces anything. Destroying a created subscription's
# resources runs Microsoft.Subscription/cancel, and a replaced network or role
# assignment means an outage, so every delete needs a deliberate, approved run.
#
# Always allowed: the vending module re-creates its management-group association
# (a PUT to the same group) when its drift trigger flips. That is not a real delete.
#
# One-off exceptions: ci/plan-gate-allow.txt, one "<request file> <resource address>"
# per line. Keep it empty except during a reviewed migration.
#
# ALLOW_DESTROY=true is set only by the vending-destroy workflow.
#
# Usage: REQUEST_FILE=subscriptions/<team>/<name>.yaml sh ci/plan-gate.sh plan.json
set -eu

PLAN="$1"
ALLOW_FILE="$(dirname "$0")/plan-gate-allow.txt"

if [ "${ALLOW_DESTROY:-false}" = "true" ]; then
  echo "ALLOW_DESTROY=true: delete gate skipped."
  exit 0
fi

# Exact addresses allowed for this request file.
ALLOWED='[]'
if [ -f "$ALLOW_FILE" ]; then
  ALLOWED=$(grep -v '^\s*#' "$ALLOW_FILE" | awk -v f="${REQUEST_FILE:-}" 'NF == 2 && $1 == f { print $2 }' | jq -R -s -c 'split("\n") | map(select(length > 0))')
fi

BLOCKED=$(jq -r --argjson allowed "$ALLOWED" '
  .resource_changes[]?
  | select(.change.actions | index("delete"))
  | select((.address | test("\\.module\\.subscription\\[0\\]\\.(azapi_resource_action\\.subscription_association|terraform_data\\.replacement)\\[0\\]$")) | not)
  | select(.address as $a | $allowed | index($a) | not)
  | "  \(.change.actions | join("/"))  \(.address)"
' "$PLAN")

if [ "$ALLOWED" != "[]" ]; then
  echo "Allowed by ci/plan-gate-allow.txt for ${REQUEST_FILE}: $ALLOWED"
fi

if [ -n "$BLOCKED" ]; then
  echo "BLOCKED: this plan deletes or replaces resources:"
  echo "$BLOCKED"
  echo "Request files are permanent (path = state key). To retire a landing zone, use the vending-destroy workflow."
  exit 1
fi

echo "Plan gate passed: nothing is deleted."
