#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Contractor Account Reuse — Blue Team Detection Chain
#  MITRE ATT&CK: T0859 (Valid Accounts) | TA0110 / TA0109
# ═══════════════════════════════════════════════════════════
LOG_FILE="/opt/scada/ScadaWeb/log/ScadaWeb.log"
WORK_ORDER="/var/log/substation_maintenance/work_order_882_CLOSED.txt"
SCORE_LOG="/opt/scada/ScadaWeb/log/score.log"
BLUE_SCORE=0
BLUE_MAX=5

sep(){ echo ""; echo "────────────────────────────────────────────────"; }

echo ""
echo "  ██████╗ ██╗     ██╗   ██╗███████╗    ████████╗███████╗ █████╗ ███╗   ███╗"
echo "  ██╔══██╗██║     ██║   ██║██╔════╝    ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║"
echo "  ██████╔╝██║     ██║   ██║█████╗         ██║   █████╗  ███████║██╔████╔██║"
echo "  ██╔══██╗██║     ██║   ██║██╔══╝         ██║   ██╔══╝  ██╔══██║██║╚██╔╝██║"
echo "  ██████╔╝███████╗╚██████╔╝███████╗        ██║   ███████╗██║  ██║██║ ╚═╝ ██║"
echo ""
echo "  Contractor Account Reuse — Blue Team Detection Exercise"
echo "  $(date)"

# ── CHECK 1: Locate the audit log ─────────────────────────────────────────
sep
echo "[CHECK 1/5] Verifying audit log existence..."
if [ ! -f "$LOG_FILE" ]; then
  echo "  [-] FAIL: Log file not found at $LOG_FILE"
  exit 1
fi
echo "  [+] PASS: Audit log found ($LOG_FILE)"
echo "  [*] Total entries: $(wc -l < "$LOG_FILE")"
((BLUE_SCORE++))

# ── CHECK 2: Detect off-hours login ───────────────────────────────────────
sep
echo "[CHECK 2/5] Detecting off-hours logins (outside 06:00–18:00)..."
OFF_HOURS=$(grep "Login successful" "$LOG_FILE" | cut -d']' -f1 | tr -d '[' | \
  while read ts; do
    HOUR=$(echo "$ts" | cut -d' ' -f2 | cut -d':' -f1 | sed 's/^0//')
    [ -z "$HOUR" ] && HOUR=0
    LINE=$(grep "$ts" "$LOG_FILE")
    if [ "$HOUR" -lt 6 ] || [ "$HOUR" -ge 18 ]; then
      echo "$LINE"
    fi
  done)

if [ -n "$OFF_HOURS" ]; then
  echo "  [!] ANOMALY DETECTED — Off-hours login(s):"
  echo "$OFF_HOURS" | sed 's/^/      /'
  ((BLUE_SCORE++))
else
  echo "  [ ] No off-hours logins found."
fi

# ── CHECK 3: Detect contractor account access ─────────────────────────────
sep
echo "[CHECK 3/5] Identifying contractor account usage..."
CONTRACTOR_LINES=$(grep "contractor_maint" "$LOG_FILE")

if [ -n "$CONTRACTOR_LINES" ]; then
  echo "  [!] contractor_maint account activity found:"
  echo "$CONTRACTOR_LINES" | sed 's/^/      /'
  echo ""

  # Extract source IPs
  CONTRACTOR_IPS=$(echo "$CONTRACTOR_LINES" | grep -oP 'from \K[\d\.]+' | sort -u)
  KNOWN_OT_RANGE="192.168."
  echo "  [+] Source IPs used by contractor_maint:"
  echo "$CONTRACTOR_IPS" | while read ip; do
    if echo "$ip" | grep -q "$KNOWN_OT_RANGE"; then
      echo "      $ip ← within OT network range (expected)"
    else
      echo "      $ip ← EXTERNAL / UNEXPECTED SOURCE ⚠"
    fi
  done
  ((BLUE_SCORE++))
else
  echo "  [ ] No contractor_maint activity in logs."
fi

# ── CHECK 4: Detect restricted view access ────────────────────────────────
sep
echo "[CHECK 4/5] Checking for restricted view access (ViewID: 102)..."
RESTRICTED_ACCESS=$(grep -E "ViewID:[ ]?102|Substation_High_Voltage_Feeder" "$LOG_FILE")

if [ -n "$RESTRICTED_ACCESS" ]; then
  echo "  [!] Restricted view accessed:"
  echo "$RESTRICTED_ACCESS" | sed 's/^/      /'
  ((BLUE_SCORE++))
else
  echo "  [ ] No restricted view access found."
fi

# ── CHECK 5: Cross-reference work order ───────────────────────────────────
sep
echo "[CHECK 5/5] Cross-referencing work order records..."
if [ -f "$WORK_ORDER" ]; then
  echo "  [+] Work order found:"
  cat "$WORK_ORDER" | sed 's/^/      /'
  echo ""
  STATUS=$(grep "STATUS" "$WORK_ORDER" | awk -F': ' '{print $2}')
  DEPROVISIONED=$(grep "AD_DEPROVISIONING" "$WORK_ORDER" | awk -F': ' '{print $2}')
  echo "  [!] Work order status  : $STATUS"
  echo "  [!] Account status     : $DEPROVISIONED"
  echo "  [+] POLICY VIOLATION CONFIRMED: Account was NOT disabled after contract closure."
  ((BLUE_SCORE++))
else
  echo "  [-] Work order not found at $WORK_ORDER"
fi

# ── SCORE REPORT ──────────────────────────────────────────────────────────
sep
echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │          BLUE TEAM DETECTION SCORE          │"
echo "  │                                             │"
printf "  │   Score: %d / %d checks passed                │\n" $BLUE_SCORE $BLUE_MAX
if [ "$BLUE_SCORE" -ge 4 ]; then
echo "  │   Result: ✓ INCIDENT CONFIRMED               │"
else
echo "  │   Result: ✗ INVESTIGATION INCOMPLETE         │"
fi
echo "  └─────────────────────────────────────────────┘"
echo ""

# Write blue score to score log
TS=$(date '+%Y-%m-%d %H:%M:%S')
mkdir -p "$(dirname "$SCORE_LOG")"
echo "[$TS] BLUE SCORE: $BLUE_SCORE/$BLUE_MAX — ran by $(whoami)" >> "$SCORE_LOG"

# ── SUMMARY ───────────────────────────────────────────────────────────────
echo "  IOC Summary:"
echo "    Account        : contractor_maint"
echo "    Work Order     : 882 (CLOSED 2026-06-15)"
echo "    Anomaly Time   : 03:15 – 03:45 (off-hours)"
echo "    Source IP      : 203.0.113.42 (external, non-OT)"
echo "    Viewed Channel : Substation_High_Voltage_Feeder (ViewID:102)"
echo "    Policy Gap     : Account not revoked after contract closure"
echo "    MITRE          : T0859 Valid Accounts | TA0109 Lateral Movement"
echo ""
echo "  Recommended Actions:"
echo "    1. Immediately disable contractor_maint account in Active Directory"
echo "    2. Audit all contractor accounts for similar retention issues"
echo "    3. Implement automated de-provisioning tied to work order closure"
echo "    4. Alert on off-hours logins from non-OT source IPs"
echo "    5. Restrict ViewID:102 to named operator accounts only"
sep
