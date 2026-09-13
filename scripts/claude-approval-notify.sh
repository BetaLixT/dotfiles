#!/bin/bash

# Claude Code PermissionRequest hook.
# Pushes an approval request to the phone via a self-hosted ntfy server and
# blocks until Approve/Deny is tapped, then returns that decision to Claude.
#
# Fail-open by design: if ntfy is not configured, the server is unreachable,
# or nobody answers before the timeout, the script exits 0 with NO output.
# Claude reads that as "no decision" and falls back to the normal local
# permission prompt. It never silently allows.
#
# Config lives OUTSIDE the repo (it holds a token):
#   ~/.config/claude-approval.env   (see claude-approval.env.example)

ENV_FILE="${CLAUDE_APPROVAL_ENV:-$HOME/.config/claude-approval.env}"
[ -r "$ENV_FILE" ] && . "$ENV_FILE"

NTFY_URL="${NTFY_URL:-}"            # e.g. http://100.x.y.z:8080  (no trailing /)
NTFY_TOPIC="${NTFY_TOPIC:-claude-approvals}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
WAIT_SECS="${WAIT_SECS:-110}"      # must stay below the hook timeout in settings.json

payload="$(cat)"

tool="$(printf '%s' "$payload" | jq -r '.tool_name // "?"' 2>/dev/null)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)"
mode="$(printf '%s' "$payload" | jq -r '.permission_mode // "default"' 2>/dev/null)"
detail="$(printf '%s' "$payload" | jq -r '
  .tool_input.command
  // .tool_input.file_path
  // .tool_input.path
  // (.tool_input | tojson)
  // ""' 2>/dev/null | head -c 400)"

APP_NAME="claude-approval"
safe="$(printf '%s' "$detail" | tr '\n' ' ' | head -c 400)"
dir="${cwd:-$PWD}"

# Where this agent is running. Herdr context wins over tmux: a Herdr pane can
# have TMUX set too, and workspace/tab/agent identifies the caller far better
# than a tmux session name does.
#
# A single `herdr api snapshot` carries the workspace label, the tab label and
# the agent name together, so resolving all three is one ~5ms round trip. The
# timeout guard matters: a wedged Herdr server must never stall an approval.
hd_ws=""; hd_tab=""; hd_agent=""
herdr_bin="${HERDR_BIN_PATH:-herdr}"
if [ "${HERDR_ENV:-}" = 1 ] && command -v "$herdr_bin" >/dev/null 2>&1; then
  snap="$(timeout 3 "$herdr_bin" api snapshot 2>/dev/null)"
  if [ -n "$snap" ]; then
    # @tsv + ${} splitting rather than `read`: with IFS=tab, read would collapse
    # empty leading fields and shift the values into the wrong variables.
    hd_tsv="$(printf '%s' "$snap" | jq -r \
      --arg ws "${HERDR_WORKSPACE_ID:-}" \
      --arg tab "${HERDR_TAB_ID:-}" \
      --arg pane "${HERDR_PANE_ID:-}" '
        .result.snapshot as $s
        | [ ([$s.workspaces[]? | select(.workspace_id == $ws) | .label] | first // ""),
            ([$s.tabs[]?       | select(.tab_id       == $tab)  | .label] | first // ""),
            ([$s.agents[]?     | select(.pane_id      == $pane) | .name]  | first // "") ]
        | @tsv' 2>/dev/null)"
    hd_ws="${hd_tsv%%$'\t'*}"
    hd_rest="${hd_tsv#*$'\t'}"
    hd_tab="${hd_rest%%$'\t'*}"
    hd_agent="${hd_rest#*$'\t'}"
  fi
fi

# Aligned " label     value" lines. An empty value drops its line entirely.
ctx=""
ctx_add() {
  [ -n "$2" ] || return 0
  local line
  printf -v line ' %-9s %s' "$1" "$2"
  ctx="${ctx}"$'\n'"${line}"
}

ctx_add tool "$tool"
ctx_add dir  "$dir"
ctx_add mode "$mode"

if [ -n "$hd_ws" ] || [ -n "$hd_tab" ]; then
  ctx_add workspace "$hd_ws"
  ctx_add tab       "$hd_tab"
elif [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  ctx_add tmux "$(tmux display-message -p -t "${TMUX_PANE:-}" '#S' 2>/dev/null)"
fi

# Agent name last, and in both branches: a Herdr-started agent still has one
# when its pane also runs tmux, and it is the most specific "who is asking".
ctx_add agent "$hd_agent"

# Compact one-line version of the same context for the phone: "ws/tab · agent".
who=""
[ -n "$hd_ws" ] && who="$hd_ws"
[ -n "$hd_tab" ] && who="${who:+$who/}$hd_tab"
[ -n "$hd_agent" ] && who="${who:+$who · }$hd_agent"
who_line=""
[ -n "$who" ] && who_line="
$who"

# Multi-line body shared by the local popup and the phone heads-up.
hint="(right-click or ✕ to dismiss)"
body="${safe}
${ctx}

${hint}"

# ntfy not configured -> approve/deny ON the mako popup itself (no window grab).
# notify-send --action blocks until an action is invoked (or the popup closes)
# and prints the chosen action name. mako maps left-click->allow and
# right-click->deny, scoped to app-name="claude-approval" (see mako/config),
# so other notifications keep their normal click behavior.
if [ -z "$NTFY_URL" ] || [ -z "$NTFY_TOKEN" ]; then
  choice="$(timeout "$((WAIT_SECS + 5))" \
    notify-send --app-name="$APP_NAME" -t "$((WAIT_SECS * 1000))" \
      --action=allow="Approve" --action=deny="Deny" \
      "Claude: approval needed" "$body" 2>/dev/null)"
  case "$choice" in
    allow) jq -n '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"allow"}}}' ;;
    deny)  jq -n '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"deny"}}}' ;;
    *)     exit 0 ;;   # dismissed / expired / no answer -> Claude prompts locally
  esac
  exit 0
fi

# ntfy configured: local heads-up only (informational); the phone is actionable.
notify-send --app-name="${APP_NAME}-info" \
  "Claude: approval needed" "${body}

 check phone to approve/deny" 2>/dev/null || true

# Unique response topic per request so verdicts never cross wires.
req="$(tr -d - < /proc/sys/kernel/random/uuid 2>/dev/null | head -c 16)"
[ -n "$req" ] || req="$$-${RANDOM}"
resp_topic="claude-resp-${req}"
since="$(date +%s)"

auth="Authorization: Bearer ${NTFY_TOKEN}"

# Publish the request with Approve / Deny buttons. Each button POSTs its
# verdict as the message body to the unique response topic.
body="$(jq -n \
  --arg topic "$NTFY_TOPIC" \
  --arg title "Claude needs approval" \
  --arg msg "$(printf '%s — %s\n(%s)%s' "$tool" "$detail" "$cwd" "$who_line")" \
  --arg url "${NTFY_URL}/${resp_topic}" \
  --arg tok "Bearer ${NTFY_TOKEN}" \
  '{
     topic: $topic, title: $title, message: $msg, priority: 5, tags: ["robot"],
     actions: [
       {action:"http", label:"✅ Approve", method:"POST", url:$url, body:"allow", clear:true, headers:{Authorization:$tok}},
       {action:"http", label:"⛔ Deny",    method:"POST", url:$url, body:"deny",  clear:true, headers:{Authorization:$tok}}
     ]
   }')"

if ! curl -s --max-time 10 -H "$auth" -H "Content-Type: application/json" \
        -d "$body" "$NTFY_URL/" >/dev/null 2>&1; then
  exit 0   # publish failed -> local prompt
fi

# Block until the first verdict arrives (or timeout). Reading from `since`
# closes the race where the button is tapped before we start listening.
verdict="$(curl -s --max-time "$WAIT_SECS" -H "$auth" \
  "$NTFY_URL/${resp_topic}/json?since=${since}" 2>/dev/null \
  | while IFS= read -r line; do
      ev="$(printf '%s' "$line" | jq -r '.event // empty' 2>/dev/null)"
      if [ "$ev" = "message" ]; then
        printf '%s' "$line" | jq -r '.message' 2>/dev/null
        break
      fi
    done)"

case "$verdict" in
  allow) jq -n '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"allow"}}}' ;;
  deny)  jq -n '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"deny"}}}' ;;
  *)     exit 0 ;;   # timeout / no answer -> local prompt
esac
