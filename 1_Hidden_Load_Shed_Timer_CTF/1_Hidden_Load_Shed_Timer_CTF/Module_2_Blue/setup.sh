#!/bin/bash
set -e

echo "[*] Setting up Blue Team OpenPLC Environment (Compromised State)..."

if ! command -v podman &> /dev/null; then
    echo "[-] Podman is not installed."
    exit 1
fi

# Verify Module 1 image exists
if ! podman image exists localhost/openplc_official:v3; then
    echo "[-] openplc_official:v3 not found. Run Module 1 setup.sh first."
    exit 1
fi

podman rm -f openplc_blue 2>/dev/null || true

mkdir -p ./investigation
mkdir -p ./evidence_logs

# ─────────────────────────────────────────────
# 2. Malicious Logic (active threat)
# ─────────────────────────────────────────────
SETUP_TMP=$(mktemp -d -p .)

cat << 'EOF' > "$SETUP_TMP/active_malicious.st"
PROGRAM malicious
  VAR
    FEEDER_1_CMD AT %QX0.0 : BOOL := TRUE;
    FEEDER_2_CMD AT %QX0.1 : BOOL := TRUE;
    FEEDER_3_CMD AT %QX0.2 : BOOL := TRUE;
  END_VAR
  VAR
    Malicious_Timer : TON;
    Timer_Reset : BOOL := FALSE;
  END_VAR

  FEEDER_1_CMD := TRUE;
  FEEDER_2_CMD := TRUE;
  Malicious_Timer(IN := NOT Timer_Reset, PT := T#60s);

  IF Malicious_Timer.Q THEN
      FEEDER_3_CMD := FALSE;
      Timer_Reset := TRUE;
  ELSE
      FEEDER_3_CMD := TRUE;
      Timer_Reset := FALSE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK TaskMain(INTERVAL := T#20ms, PRIORITY := 0);
    PROGRAM Inst0 WITH TaskMain : malicious;
  END_RESOURCE
END_CONFIGURATION
EOF

# ─────────────────────────────────────────────
# 3. Fake audit logs (forensic artifact)
# ─────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
cat << EOF > ./evidence_logs/openplc_audit.log
[INFO] $TIMESTAMP - Admin logged in from 10.10.50.15
[WARN] $TIMESTAMP - SYSTEM: active_program.st overwritten via WebAPI
[INFO] $TIMESTAMP - SYSTEM: OpenPLC Runtime Restart Triggered
EOF

# ─────────────────────────────────────────────
# 4. Deploy using local image from Module 1
# ─────────────────────────────────────────────
# Allow rootless Podman to bind privileged ports (< 1024)
echo "[*] Lowering unprivileged port start for Modbus/502 binding..."
if [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)" -gt 502 ]; then
    sudo sysctl -w net.ipv4.ip_unprivileged_port_start=502 || {
        echo "[!] Could not set ip_unprivileged_port_start. Using host port 5021 instead."
        MODBUS_PORT=5021
    }
fi
MODBUS_PORT=${MODBUS_PORT:-502}

echo "[*] Starting OpenPLC container (Blue Team instance)..."
podman run -d \
    --name openplc_blue \
    -p 8081:8080 \
    -p ${MODBUS_PORT}:502 \
    localhost/openplc_official:v3

echo "[*] Waiting 15 seconds for runtime initialization..."
sleep 15

# ─────────────────────────────────────────────
# 5. Inject malicious program (pre-compromised state)
# ─────────────────────────────────────────────
echo "[*] Injecting malicious ST program..."
podman cp "$SETUP_TMP/active_malicious.st" \
    openplc_blue:/docker_persistent/st_files/active_malicious.st

podman exec openplc_blue bash -c \
    "echo 'active_malicious.st' > /docker_persistent/active_program"

# Inject baseline and malicious programs into SQL database
podman exec openplc_blue python3 -c \
    "import sqlite3; conn = sqlite3.connect('/docker_persistent/openplc.db'); cur = conn.cursor(); cur.execute(\"INSERT OR REPLACE INTO Programs (Prog_ID, Name, Description, File, Date_upload) VALUES (18, 'baseline', 'Baseline program', 'baseline.st', 1527184953)\"); cur.execute(\"INSERT OR REPLACE INTO Programs (Prog_ID, Name, Description, File, Date_upload) VALUES (19, 'active_malicious', 'Malicious program', 'active_malicious.st', 1527184953)\"); conn.commit(); conn.close()"

# Copy audit logs into container for participants to find
podman cp ./evidence_logs/openplc_audit.log \
    openplc_blue:/docker_persistent/openplc_audit.log

# Clean up temporary directory
rm -rf "$SETUP_TMP"

echo "[*] Restarting to load compromised state..."
podman stop openplc_blue
sleep 2
podman start openplc_blue
sleep 8

# ─────────────────────────────────────────────
# 6. Verify
# ─────────────────────────────────────────────
ACTIVE=$(podman exec openplc_blue bash -c "cat /docker_persistent/active_program" 2>/dev/null)
echo ""
echo "[+] ──────────────────────────────────────────────"
echo "[+]  Blue Team Environment Ready"
echo "[+] ──────────────────────────────────────────────"
echo "[+]  Dashboard     : http://localhost:8081"
echo "[+]  Modbus TCP    : localhost:${MODBUS_PORT:-502}"
echo "[+]  Credentials   : openplc / openplc"
echo "[+]  Active PLC    : $ACTIVE"
echo "[+]  Audit log     : ./evidence_logs/openplc_audit.log"
echo "[+]  Baseline hash : ./investigation/baseline_hash.txt"
echo "[+] ──────────────────────────────────────────────"