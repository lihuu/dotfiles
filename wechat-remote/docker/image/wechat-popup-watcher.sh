#!/bin/sh
# Keep WeChat utility popups next to the main window instead of the startup coord.
#
# Background (verified by experiment, see docs/superpowers/handoffs/):
#   Linux WeChat (CEF / WeChatAppEx) positions each utility popup (emoji panel
#   etc.) at a fixed startup coordinate (+0+124) at the moment it transitions
#   UnMapped -> IsViewable. After that initial placement, CEF does NOT keep
#   repositioning the popup while it stays visible.
#
#   Therefore moving the popup ONCE, right after it becomes visible, is stable:
#   CEF accepts the new position and never fights back. The earlier "once-only"
#   versions jumped left/right because the watcher kept re-checking and re-moving
#   every polling interval while the popup was visible, which triggered CEF's
#   position-change feedback and created an oscillation.
#
# Correct strategy (this file):
#   - Track each popup's previous Map State.
#   - Only act on the UnMapped -> IsViewable transition: move once, mark as seen.
#   - While a popup stays IsViewable, NEVER move it again (this prevents jumping).
#   - When it goes back to IsUnMapped, clear its "seen" record so the next open
#     is handled again.
#
# Container/xpra uses decorations=1 so the main window can be dragged on macOS.
# Some WeChat utility popups still appear at the old startup coordinate.

set -u

DISPLAY_ARG="${DISPLAY:-:10}"
INTERVAL="${WECHAT_POPUP_WATCH_INTERVAL:-0.25}"
OFFSET_X="${WECHAT_POPUP_OFFSET_X:-0}"
OFFSET_Y="${WECHAT_POPUP_OFFSET_Y:-124}"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wechat-popup-watcher.state"

geom_value() {
  xwininfo -id "$1" 2>/dev/null | awk -F: -v key="$2" '$1 ~ key {gsub(/^[ \t]+/, "", $2); print $2; exit}'
}

is_viewable() {
  [ "$(geom_value "$1" "Map State")" = "IsViewable" ]
}

abs_x() {
  geom_value "$1" "Absolute upper-left X"
}

abs_y() {
  geom_value "$1" "Absolute upper-left Y"
}

width_of() {
  geom_value "$1" "Width"
}

height_of() {
  geom_value "$1" "Height"
}

has_prop() {
  xprop -id "$1" "$2" 2>/dev/null | grep -q "$3"
}

find_main_window() {
  # WeChat may expose two same-named "微信" windows:
  #   - a hidden fallback (IsUnMapped, has _KDE_NET_WM_WINDOW_TYPE_OVERRIDE, no WM_STATE)
  #   - the real active main window (IsViewable, _NET_WM_WINDOW_TYPE_NORMAL, WM_STATE=Normal)
  # The active main window as forwarded by xpra may lack WM_CLASS, so
  # `xdotool search --class wechat` can miss it. Search by --name instead and
  # require IsViewable + WM_STATE=Normal, then pick the largest by area.
  best=""
  best_area=0
  for wid in $(xdotool search --name "微信" 2>/dev/null || true); do
    is_viewable "$wid" || continue
    # WM_STATE=Normal filters out tray / minimized windows
    has_prop "$wid" WM_STATE "window state: Normal" || continue
    w=$(width_of "$wid")
    h=$(height_of "$wid")
    case "$w:$h" in
      *[!0-9:]*|:) continue ;;
    esac
    area=$((w * h))
    if [ "$area" -gt "$best_area" ]; then
      best_area=$area
      best="$wid"
    fi
  done
  [ -n "$best" ] && printf '%s\n' "$best"
}

is_utility_popup() {
  # WeChat utility popups: UTILITY window type, reasonably large (emoji panel
  # is ~1028x1040). Skip tray icons and tiny helper windows.
  wid="$1"
  has_prop "$wid" _NET_WM_WINDOW_TYPE "_NET_WM_WINDOW_TYPE_UTILITY" || return 1
  w=$(width_of "$wid")
  h=$(height_of "$wid")
  case "$w:$h" in
    *[!0-9:]*|:) return 1 ;;
  esac
  [ "$w" -gt 300 ] && [ "$h" -gt 300 ]
}

move_once() {
  # Move a freshly-mapped popup next to the main window. Single shot: the caller
  # guarantees this only runs on the UnMapped -> IsViewable transition, AND has
  # already marked the popup as "moved-visible" in STATE_FILE before calling us,
  # so no concurrent re-entry can move it again.
  wid="$1"
  main="$2"
  main_x=$(abs_x "$main")
  main_y=$(abs_y "$main")
  case "$main_x:$main_y" in
    *[!0-9:-]*|:) return ;;
  esac

  target_x=$((main_x + OFFSET_X))
  target_y=$((main_y + OFFSET_Y))

  # CEF sets the popup position at map time and may make a couple of rapid
  # adjustments in the first few tens of ms. Wait until the popup's own
  # coordinate stops changing (two consecutive identical reads), then move
  # once. This minimises the visible flash at the old position without moving
  # so early that CEF's initial placement is still in flux.
  # Hard cap ~0.5s so we never block the loop indefinitely.
  prev_x=""
  prev_y=""
  i=0
  while [ "$i" -lt 10 ]; do
    is_viewable "$wid" || return
    cur_x=$(abs_x "$wid")
    cur_y=$(abs_y "$wid")
    case "$cur_x:$cur_y" in
      *[!0-9:-]*|:) return ;;
    esac
    if [ "$cur_x" = "$prev_x" ] && [ "$cur_y" = "$prev_y" ]; then
      break
    fi
    prev_x="$cur_x"
    prev_y="$cur_y"
    i=$((i + 1))
    sleep 0.05
  done

  is_viewable "$wid" || return
  xdotool windowmove "$wid" "$target_x" "$target_y" >/dev/null 2>&1 || true
}

# state file format: "<wid> <IsViewable|IsUnMapped>" per line, for popups we
# have already moved. We only need to remember popups that are currently visible
# (so we don't move them again). When a popup becomes unmapped, drop it.
load_state() {
  [ -f "$STATE_FILE" ] && cat "$STATE_FILE" 2>/dev/null || true
}

# Returns 0 (true) if wid is currently marked as "moved & visible".
was_moved_visible() {
  grep -qx "$1 IsViewable" "$STATE_FILE" 2>/dev/null
}

# Rewrite the state file with the given set of "wid state" lines.
save_state() {
  tmp="${STATE_FILE}.tmp"
  : > "$tmp"
  while IFS= read -r line; do
    [ -n "$line" ] && printf '%s\n' "$line" >> "$tmp"
  done
  mv "$tmp" "$STATE_FILE" 2>/dev/null || true
}

export DISPLAY="$DISPLAY_ARG"
rm -f "$STATE_FILE"

NL='
'

while :; do
  main="$(find_main_window || true)"
  if [ -n "$main" ]; then
    new_state=""
    # Walk every wechat-class window; act on utility popups.
    for wid in $(xdotool search --class wechat 2>/dev/null || true); do
      [ "$wid" != "$main" ] || continue
      is_utility_popup "$wid" || continue

      if is_viewable "$wid"; then
        if was_moved_visible "$wid"; then
          # Already moved for this visible session; leave it alone. This is the
          # anti-jumping guarantee: no repeated windowmove while visible.
          new_state="${new_state}${wid} IsViewable${NL}"
        else
          # Fresh transition to visible. CRITICAL: mark as moved FIRST (flush to
          # STATE_FILE), THEN call move_once. This way the next polling iteration
          # sees it as already-moved and never re-enters move_once, which would
          # trigger CEF's position feedback -> jumping.
          new_state="${new_state}${wid} IsViewable${NL}"
          printf '%s' "$new_state" > "$STATE_FILE"
          move_once "$wid" "$main"
        fi
      fi
      # Not visible: omit from new_state so next open re-triggers a move.
    done
    printf '%s' "$new_state" > "$STATE_FILE"
  fi
  sleep "$INTERVAL"
done
