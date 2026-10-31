#!/bin/bash
# Posture Reminder for macOS
#
# Shows a pop-up after every hour of continuous use, telling you to get up
# or shift position. The pop-up stays until you click it and has a
# "Stop for today" button. Runs quietly in the background: no Dock or
# menu bar icon, and it starts again automatically each time you log in.
#
#   Install:    bash install-posture-reminder.sh
#   Test it:    bash install-posture-reminder.sh test
#   Uninstall:  bash install-posture-reminder.sh uninstall
#
# Creates 1 folder (containing some files) and one file:
#
#   ~/Library/Application Support/PostureReminder
#   ~/Library/LaunchAgents/com.user.posturereminder.plist
#
# Deleting the folder and file removes every trace of this
# Also would need to restart computer otherwise it would silently fail every minute (uninstall script handles this)

set -e

LABEL="com.user.posturereminder"
APP_DIR="$HOME/Library/Application Support/PostureReminder"
SCRIPT="$APP_DIR/remind.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

case "$1" in
  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    rm -rf "$APP_DIR"
    echo "Posture Reminder removed."
    exit 0
    ;;
  test)
    if [ ! -f "$SCRIPT" ]; then echo "Install it first."; exit 1; fi
    bash "$SCRIPT" --now
    exit 0
    ;;
esac

mkdir -p "$APP_DIR" "$HOME/Library/LaunchAgents"

# ---------------------------------------------------------------------------
# The reminder script. macOS runs this once a minute in the background.
# ---------------------------------------------------------------------------
cat > "$SCRIPT" <<'SCRIPT_EOF'
#!/bin/bash
# --- Settings you can change --------------------------------------------
INTERVAL=3600   # seconds of continuous use before a reminder (3600 = 1 hour)
BREAK=300       # seconds away from the laptop that count as a break (5 min)
MESSAGE="STAND UP OR STRETCH"
# ------------------------------------------------------------------------

STATE="$HOME/Library/Application Support/PostureReminder"
now=$(date +%s)
today=$(date +%Y-%m-%d)

show_popup() {
  osascript <<EOF 2>/dev/null
tell me to activate
set r to display dialog "$MESSAGE" with title "Posture break" buttons {"Stop for today", "OK"} default button "OK" with icon note
return button returned of r
EOF
}

# Manual test: show the pop-up right away.
if [ "$1" = "--now" ]; then
  show_popup >/dev/null
  exit 0
fi

# Already stopped for today? Do nothing until tomorrow.
if [ "$(cat "$STATE/stopped_on" 2>/dev/null)" = "$today" ]; then
  exit 0
fi

# Seconds since the last keyboard/mouse/trackpad input.
idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
idle=${idle:-0}

last_check=$(cat "$STATE/last_check" 2>/dev/null || echo 0)
start=$(cat "$STATE/use_started" 2>/dev/null || echo "$now")
echo "$now" > "$STATE/last_check"

# A break restarts the hour: you were idle a while, or the laptop was
# asleep or closed (no check has run for a while).
if [ "$idle" -ge "$BREAK" ] || [ $((now - last_check)) -ge "$BREAK" ]; then
  echo "$now" > "$STATE/use_started"
  exit 0
fi

# Not an hour of use yet.
if [ $((now - start)) -lt "$INTERVAL" ]; then
  echo "$start" > "$STATE/use_started"
  exit 0
fi

# An hour of use: show the pop-up and wait for a click.
answer=$(show_popup)
if [ "$answer" = "Stop for today" ]; then
  echo "$today" > "$STATE/stopped_on"
fi

# Start the next hour from when you clicked.
now=$(date +%s)
echo "$now" > "$STATE/use_started"
echo "$now" > "$STATE/last_check"
SCRIPT_EOF
chmod +x "$SCRIPT"

# ---------------------------------------------------------------------------
# Tell macOS to run the script every minute, starting at each login.
# ---------------------------------------------------------------------------
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
PLIST_EOF

# (Re)load it so it starts now without a restart.
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"

echo "Posture Reminder installed. You'll get a pop-up after each hour of use."
echo "Preview the pop-up:  bash \"$0\" test"
echo "Remove it:           bash \"$0\" uninstall"
