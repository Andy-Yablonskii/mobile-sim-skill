#!/usr/bin/env bash
# Drive the booted iOS Simulator with AXe + simctl.
#   sim.sh udid                               booted device UDID (override with SIM_UDID)
#   sim.sh shot [name]                        screenshot → $OUT/<name>.png and <name>_pt.png (1 px = 1 pt = tap coords)
#   sim.sh ui [filter]                        flattened accessibility tree: [Type] 'label' @(x,y) WxH
#   sim.sh tap <x> <y>  |  tap-label <label>  tap a point, or an element by accessibility label
#   sim.sh type <text>                        type into the focused field
#   sim.sh swipe <x1> <y1> <x2> <y2> [secs]   swipe; a slow one (1.2s) drags floating elements
#   sim.sh open <url>                         open a deep link (e.g. an Expo dev-client URL)
#   sim.sh jslog [minutes]                    recent React Native JS logs from the device log
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UDID="${SIM_UDID:-$(xcrun simctl list devices booted -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
booted = [d["udid"] for runtime in devices.values() for d in runtime if d["state"] == "Booted"]
print(booted[0] if booted else "")')}"
[ -n "$UDID" ] || { echo "No booted simulator — boot one: xcrun simctl boot <UDID> && open -a Simulator" >&2; exit 1; }
command -v axe >/dev/null || { echo "AXe missing — brew install cameroncooke/axe/axe" >&2; exit 1; }
OUT="${SIM_OUT:-${TMPDIR:-/tmp}/mobile-sim}"
mkdir -p "$OUT"

cmd="${1:-help}"
shift || true
case "$cmd" in
  udid) echo "$UDID" ;;
  shot)
    name="${1:-shot-$(date +%H%M%S)}"
    xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
    points_high=$(axe describe-ui --udid "$UDID" | python3 -c 'import json, sys; print(int(json.load(sys.stdin)[0]["frame"]["height"]))')
    sips -Z "$points_high" "$OUT/$name.png" --out "$OUT/${name}_pt.png" >/dev/null
    echo "$OUT/${name}_pt.png" ;;
  ui) python3 "$here/ui.py" "$UDID" "${1:-}" ;;
  tap) axe tap -x "$1" -y "$2" --udid "$UDID" >/dev/null && echo "tapped $1,$2" ;;
  tap-label) axe tap --label "$1" --udid "$UDID" >/dev/null && echo "tapped '$1'" ;;
  type) axe type "$1" --udid "$UDID" >/dev/null && echo "typed" ;;
  swipe) axe swipe --start-x "$1" --start-y "$2" --end-x "$3" --end-y "$4" --duration "${5:-0.4}" --udid "$UDID" >/dev/null && echo "swiped" ;;
  open) xcrun simctl openurl "$UDID" "$1" && echo "opened" ;;
  jslog) xcrun simctl spawn "$UDID" log show --last "${1:-2}m" --style compact \
           --predicate 'subsystem == "com.facebook.react.log"' 2>/dev/null | tail -n 80 ;;
  *) sed -n '2,11p' "$0"; exit 1 ;;
esac
