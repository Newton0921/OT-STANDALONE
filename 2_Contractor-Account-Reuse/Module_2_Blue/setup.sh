#!/bin/bash
# Contractor Account Reuse — Blue Module Setup
# Plants forensic evidence THEN runs the red attack to create real log entries
set -e

if [ "$EUID" -ne 0 ]; then echo "[-] Run as root."; exit 1; fi

echo "[*] Blue Module — Forensic Environment Setup"

# ── 1. Ensure Red module is up (start it if not running) ─────────────────
RED_SETUP="$(dirname "$0")/../Module_1_Red/setup.sh"
if ! systemctl is-active --quiet scada-web.service 2>/dev/null; then
  echo "[*] SCADA not running — launching Red environment first..."
  bash "$RED_SETUP"
else
  echo "[*] SCADA already running — reusing existing environment."
fi

# ── 2. Ensure baseline log exists (Red setup already seeds it) ────────────
LOG_FILE="/opt/scada/ScadaWeb/log/ScadaWeb.log"
mkdir -p "$(dirname "$LOG_FILE")"

# ── 3. Execute the actual attack to generate real log entries ────────────────
echo "[*] Executing real attack simulation with spoofed headers to generate live logs..."
SPOOF_IP="203.0.113.42" SPOOF_TIME="2026-06-18 03:15:22" bash "$(dirname "$0")/../Module_1_Red/red_attack.sh" 127.0.0.1 >/dev/null


# ── 4. Closed Work Order ─────────────────────────────────────────────────
mkdir -p /var/log/substation_maintenance
cat > /var/log/substation_maintenance/work_order_882_CLOSED.txt << 'WOEOF'
WORK ORDER: 882
SYSTEM: Substation High Voltage Feeder (SUB_115K_HV)
TECHNICIAN: contractor_maint
ROLE: Maintenance Contractor (3rd Party — PowerServ Ltd)
STATUS: CLOSED
START_DATE: 2026-06-13
END_DATE:   2026-06-15
REVIEWED_BY: Engineer1
NOTES: Physical HV feeder inspection complete. System returned to operational.
AD_DEPROVISIONING: PENDING — contractor_maint account NOT yet disabled as of 2026-06-18.
WOEOF

echo "[+] Forensic environment ready."
echo "[+] Log file    : $LOG_FILE"
echo "[+] Work order  : /var/log/substation_maintenance/work_order_882_CLOSED.txt"
echo "[+] Score log   : /opt/scada/ScadaWeb/log/score.log"
echo ""
echo "[*] Run the Blue detection script: bash blue_detect.sh"