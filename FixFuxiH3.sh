#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIG_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
CONF_FILE="$CONFIG_DIR/51-usb-headset-fix.conf"
ALSA_FILE="/etc/modprobe.d/usb-headset.conf"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/fixfuxi-volume.service"
TIMER_FILE="$SYSTEMD_USER_DIR/fixfuxi-volume.timer"

QUIET=0
DEBUG=0
VOLUME_ONLY=0
INSTALL_ONLY=0
NO_PERSIST=0
VOLUME_RETRY_COUNT=10
VOLUME_RETRY_DELAY_SEC=3

log() {
  if [ "$QUIET" -eq 0 ]; then
    echo "$@"
  fi
}

log_debug() {
  if [ "$DEBUG" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
    echo "[debug] $@"
  fi
}

get_control_percent() {
  local card control
  card="$1"
  control="$2"

  amixer -c "$card" sget "$control" 2>/dev/null | sed -n 's/.*\[\([0-9][0-9]*\)%\].*/\1/p' | head -n 1
}

usage() {
  cat << 'EOF'
Usage:
  ./FixFuxiH3.sh [options]

Options:
  --volume-only   Adjust only ALSA output volume for Fuxi cards.
  --install-only  Install/update user-level systemd persistence.
  --no-persist    Do not install persistence in default mode.
  --debug         Enable detailed logs.
  --quiet         Reduce logs.
  -h, --help      Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --volume-only)
      VOLUME_ONLY=1
      ;;
    --install-only)
      INSTALL_ONLY=1
      ;;
    --no-persist)
      NO_PERSIST=1
      ;;
    --debug)
      DEBUG=1
      ;;
    --quiet)
      QUIET=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

get_fuxi_cards() {
  {
    aplay -l 2>/dev/null | awk '
      BEGIN { IGNORECASE = 1 }
      /^card [0-9]+:|^placa [0-9]+:/ {
        if (tolower($0) ~ /fuxi/) {
          gsub(":", "", $2)
          print $2
        }
      }
    '

    awk '
      BEGIN { IGNORECASE = 1 }
      tolower($0) ~ /fuxi/ && $1 ~ /^[0-9]+$/ {
        print $1
      }
    ' /proc/asound/cards 2>/dev/null
  } | sort -u
}

is_output_control() {
  local control
  control="$1"

  if echo "$control" | grep -Eqi '(capture|mic|microphone|input|boost)'; then
    return 1
  fi

  if echo "$control" | grep -Eqi '(master|pcm|speaker|headphone|front|line|playback|surround)'; then
    return 0
  fi

  return 1
}

apply_volume_for_card() {
  local card controls control_id control_name matched before_percent after_percent
  card="$1"
  matched=0

  log "Adjusting Fuxi card: $card"

  controls=$(amixer -c "$card" scontrols 2>/dev/null | sed -n 's/^Simple mixer control //p')

  if [ -n "$controls" ]; then
    while read -r control_id; do
      [ -z "$control_id" ] && continue

      control_name=$(echo "$control_id" | sed -E "s/^'([^']*)'.*/\1/")

      if is_output_control "$control_name"; then
        matched=1
        before_percent="$(get_control_percent "$card" "$control_id" || true)"
        log "  -> setting $control_id to 100%"
        amixer -c "$card" sset "$control_id" 100% unmute >/dev/null 2>&1 || true
        after_percent="$(get_control_percent "$card" "$control_id" || true)"
        log_debug "card=$card control=$control_id before=${before_percent:-n/a}% after=${after_percent:-n/a}%"
      fi
    done << EOF
$controls
EOF
  fi

  if [ "$matched" -eq 0 ]; then
    # Fallback for mixers that do not expose standard control names.
    amixer -c "$card" sset Master 100% unmute >/dev/null 2>&1 || true
    amixer -c "$card" sset PCM 100%,100% >/dev/null 2>&1 || true
    amixer -c "$card" sset 'PCM 1' 100% >/dev/null 2>&1 || true
    amixer -c "$card" sset Headphone 100% unmute >/dev/null 2>&1 || true
    amixer -c "$card" sset Speaker 100% unmute >/dev/null 2>&1 || true
  fi
}

apply_fuxi_output_volume() {
  local cards
  cards="$(get_fuxi_cards)"

  if [ -z "$cards" ]; then
    log "No Fuxi card found at the moment."
    return 1
  fi

  log_debug "detected Fuxi cards: $(echo "$cards" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

  while read -r card; do
    [ -z "$card" ] && continue
    apply_volume_for_card "$card"
  done << EOF
$cards
EOF
}

apply_fuxi_output_volume_with_retry() {
  local attempt

  attempt=1
  while [ "$attempt" -le "$VOLUME_RETRY_COUNT" ]; do
    log_debug "attempt $attempt/$VOLUME_RETRY_COUNT to detect and adjust Fuxi cards"
    if apply_fuxi_output_volume; then
      return 0
    fi

    sleep "$VOLUME_RETRY_DELAY_SEC"
    attempt=$((attempt + 1))
  done

  # Do not fail the service; only log that no card was found in the retry window.
  log "Could not detect a Fuxi card after $((VOLUME_RETRY_COUNT * VOLUME_RETRY_DELAY_SEC))s."
  return 0
}

write_wireplumber_patch() {
  log "Creating WirePlumber configuration directory..."
  mkdir -p "$CONFIG_DIR"

  log "Generating audio patch for USB headsets..."

  cat > "$CONF_FILE" << 'EOF'
monitor.alsa.rules = [

  {
  matches = [
    {
    device.name = "~alsa_card.usb.*"
    }
  ]

  actions = {
    update-props = {

    # Avoid suspend behavior that breaks audio.
    session.suspend-timeout-seconds = 0

    # Use software mixer (fixes buggy USB headsets).
    api.alsa.soft-mixer = true

    # Avoid USB batch scheduling issues.
    api.alsa.disable-batch = true

    # Ignore broken dB reporting on USB devices.
    api.alsa.ignore-dB = true

    # Force stereo channel layout.
    audio.channels = 2
    audio.position = [ FL FR ]

    # Avoid mono fallback.
    api.alsa.use-acp = false

    # Improve audio initialization timing.
    api.alsa.start-delay = 1

    # Force initial volume.
    node.initial-volume = 1.0
    node.volume = 1.0
    }
  }
  }

]
EOF

  log "WirePlumber patch created:"
  log "$CONF_FILE"
  log ""
}

configure_alsa_kernel_stability() {
  log "Configuring ALSA to improve USB stability..."

  if [ ! -f "$ALSA_FILE" ]; then
    echo "options snd_usb_audio nrpacks=1" | sudo tee "$ALSA_FILE" > /dev/null
  elif ! grep -q nrpacks "$ALSA_FILE"; then
    echo "options snd_usb_audio nrpacks=1" | sudo tee -a "$ALSA_FILE" > /dev/null
  fi

  log "ALSA configuration applied."
  log ""
}

restart_audio_services() {
  log "Restarting audio services..."

  systemctl --user restart wireplumber 2>/dev/null || true
  systemctl --user restart pipewire 2>/dev/null || true
  systemctl --user restart pipewire-pulse 2>/dev/null || true

  log ""
}

install_persistence() {
  mkdir -p "$SYSTEMD_USER_DIR"

  cat > "$SERVICE_FILE" << EOF
[Unit]
Description=FixFuxi - Reapply headset output volume
After=wireplumber.service pipewire.service
Wants=wireplumber.service pipewire.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --volume-only --debug
NoNewPrivileges=true

[Install]
WantedBy=default.target
EOF

  cat > "$TIMER_FILE" << 'EOF'
[Unit]
Description=FixFuxi - Periodic volume reapplication

[Timer]
OnStartupSec=10s
OnCalendar=*-*-* *:*:0/20
AccuracySec=1s
Persistent=true
Unit=fixfuxi-volume.service

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now fixfuxi-volume.timer >/dev/null
  systemctl --user start fixfuxi-volume.service >/dev/null 2>&1 || true

  log "Persistence installed successfully."
  log "Active timer: fixfuxi-volume.timer (reapplies every 20s)."
}

run_full_fix() {
  log "=========================================="
  log "  USB Headset Audio Fix (PipeWire/Linux)"
  log "=========================================="
  log ""

  write_wireplumber_patch
  configure_alsa_kernel_stability
  restart_audio_services

  log "Adjusting ALSA mixers (output)..."
  sleep 2
  apply_fuxi_output_volume

  log ""
  log "=========================================="
  log "Fix applied successfully."
  log "=========================================="
}

if [ "$INSTALL_ONLY" -eq 1 ]; then
  install_persistence
  exit 0
fi

if [ "$VOLUME_ONLY" -eq 1 ]; then
  apply_fuxi_output_volume_with_retry
  exit 0
fi

run_full_fix

if [ "$NO_PERSIST" -eq 0 ]; then
  install_persistence
  log "Persistence enabled for session startup and headset reconnection."
fi
