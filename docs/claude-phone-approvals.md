# Claude Code → phone approvals (ntfy + Tailscale)

Push a notification to the phone whenever Claude Code would ask for permission,
tap **Approve** / **Deny**, and have that decision flow back into Claude.

## How it works

```
Claude would prompt  →  PermissionRequest hook (scripts/claude-approval-notify.sh)

  ntfy NOT configured (local mode):
   → swaync popup with real [Approve] [Deny] buttons (right-click/✕ = dismiss)
       ├─ Approve → decision.behavior=allow
       ├─ Deny    → decision.behavior=deny
       └─ dismissed/expired → exit 0, no output → normal terminal prompt (fail-open)

  ntfy configured (remote mode):
   → local swaync heads-up ("check phone")
   → ntfy publish to "claude-approvals" with Approve/Deny buttons → 📱
   → hook blocks on ntfy "claude-resp-<id>" (up to WAIT_SECS)
       ├─ Approve/Deny tapped → decision.behavior=allow/deny
       └─ timeout/unreachable → exit 0, no output → normal terminal prompt
```

- Hook: `PermissionRequest` — fires **only** when Claude would actually prompt
  (not on auto-approved reads), so no notification spam.
- Local mode uses swaync (replaced mako as the notification daemon). The hook's
  `notify-send --action` renders as clickable buttons; theming is in
  `swaync/style.css` (Kanagawa). Install: `sudo pacman -S swaync`.
- Fail-open: if you don't answer (or ntfy is down/unconfigured), Claude falls
  back to the terminal prompt. It never silently allows.

## One-time setup

### 1. Tailscale (so the phone reaches the laptop from anywhere)
```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up            # opens a login URL
tailscale ip -4              # note this 100.x.y.z address
```
Install the Tailscale app on the phone and log into the same tailnet.

### 2. ntfy server
```bash
sudo pacman -S ntfy
sudo install -Dm644 ~/dotfiles/system/ntfy-server.example.yml /etc/ntfy/server.yml
sudoedit /etc/ntfy/server.yml         # set base-url to http://100.x.y.z:8080
sudo systemctl enable --now ntfy
sudo ntfy user add --role=user claude # set a password
sudo ntfy access claude "claude-*" rw
sudo ntfy token add claude            # prints tk_... — used below and on the phone
```

### 3. Hook config (secret, outside the repo)
```bash
cp ~/dotfiles/scripts/claude-approval.env.example ~/.config/claude-approval.env
$EDITOR ~/.config/claude-approval.env   # set NTFY_URL (tailscale IP) + NTFY_TOKEN
```

### 4. Phone app
Install **ntfy** (F-Droid / Play / App Store) → add server `http://100.x.y.z:8080`
with the token → subscribe to topic `claude-approvals`.

### 5. settings.json
Already wired: `~/.claude/settings.json` runs `scripts/claude-approval-notify.sh`
as a second `PermissionRequest` hook (alongside the orca telemetry hook),
`timeout: 120`.

## Test the loop
```bash
# Simulate the hook payload once the env file + ntfy are live:
echo '{"tool_name":"Bash","cwd":"/home/dcruza","tool_input":{"command":"echo hi"}}' \
  | ~/dotfiles/scripts/claude-approval-notify.sh
```
Phone should buzz with Approve/Deny; tapping prints the decision JSON and the
command returns. Then try a real Claude action that needs permission.

## Tuning
- Notify only for shell/writes instead of everything: change the new hook's
  `matcher` in settings.json from `"*"` to `"Bash|Edit|Write"`.
- Longer/shorter wait: `WAIT_SECS` in the env file (keep < the 120 hook timeout).
