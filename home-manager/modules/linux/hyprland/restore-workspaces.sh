# Puts workspaces back on the monitor their `workspace = N, monitor:...' rule
# names.
#
# `dpms off' does not merely blank these panels: the LGs drop the link, the
# kernel reports a disconnect, and Hyprland destroys the outputs outright (the
# same teardown that forces the hyprpanel restart in hyprland.nix). Every
# workspace living on a destroyed output is evacuated to a surviving one, and
# on reconnect Hyprland only pulls back the workspace marked `default:true' --
# 1 comes home, 2-5 stay behind on the right-hand panel with all their windows.
#
# The pinning lives in hyprland.conf, so nothing is hardcoded here: the rules
# are read back out of the running compositor via `hyprctl workspacerules'.
# Rules naming a monitor that is not currently connected resolve to nothing and
# are skipped, so this is safe to run at any time, including with the Prompter
# unplugged.

set -euo pipefail

monitors=$(hyprctl -j monitors)
workspaces=$(hyprctl -j workspaces)
rules=$(hyprctl -j workspacerules)

# Restored at the end: moveworkspacetomonitor makes the moved workspace active
# on its destination, so without this the left panel is left showing whichever
# workspace happened to be moved last.
focused_monitor=$(printf '%s' "$monitors" | jq -r '.[] | select(.focused) | .name')
focused_workspace=$(printf '%s' "$monitors" | jq -r '.[] | select(.focused) | .activeWorkspace.id')

# One "<workspace id> <monitor name>" line per workspace that is on the wrong
# output. `desc:' is matched as a prefix, the way Hyprland itself matches it.
moves=$(jq -rn \
  --argjson mons "$monitors" \
  --argjson wss "$workspaces" \
  --argjson rules "$rules" '
  def resolve($spec):
    if ($spec | startswith("desc:"))
    then ($spec | ltrimstr("desc:")) as $d
         | $mons[] | select(.description | startswith($d)) | .name
    else $mons[] | select(.name == $spec) | .name
    end;

  $rules[]
  | select(.monitor != null and .monitor != "")
  | select(.workspaceString | test("^[0-9]+$"))
  | (.workspaceString | tonumber) as $id
  | resolve(.monitor) as $target
  | ($wss[] | select(.id == $id)) as $ws
  | select($ws.monitor != $target)
  | "\($id) \($target)"
')

[ -n "$moves" ] || exit 0

batch=""
while read -r id target; do
  batch="$batch dispatch moveworkspacetomonitor $id $target ;"
  echo "restoring workspace $id -> $target" >&2
done <<EOF
$moves
EOF

hyprctl --batch "$batch" >/dev/null

# Focus last so the visible workspace on each panel is the one that was there
# before, not the tail of the move list. Deliberately a second call: moving an
# *empty* workspace off a monitor destroys it, and that destruction lands after
# the batch is drained -- the fallback it then picks overwrites a focus
# dispatch issued in the same batch.
sleep 1
hyprctl --batch "dispatch focusmonitor $focused_monitor ; dispatch workspace $focused_workspace ;" >/dev/null
