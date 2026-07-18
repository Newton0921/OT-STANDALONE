#!/bin/bash
set -e

echo "[*] Initializing Operation Shadow Garden Enclave..."

# Cleanup any failed previous runs
podman rm -f openplc_shadow 2>/dev/null || true

# Create temporary setup directory
SETUP_TMP=$(mktemp -d -p .)

# ─────────────────────────────────────────────
# 2. Clone + Build (no-cache to bust stale layers)
# ─────────────────────────────────────────────
if podman image exists localhost/openplc_official:v3 || podman image exists openplc_official:v3; then
    echo "[*] Image openplc_official:v3 already exists, skipping clone and build."
else
    echo "[*] Cloning official OpenPLC_v3 repository..."
    if [ ! -d "OpenPLC_v3" ]; then
        git clone https://github.com/thiagoralves/OpenPLC_v3.git
    fi

    echo "[*] Building OpenPLC_v3 image (no-cache — ~5-10 min)..."
    cd OpenPLC_v3
    podman build --no-cache --network=host -t openplc_official:v3 .
    cd ..
fi

# Sanity-check the entrypoint actually exists in the image
echo "[*] Verifying image entrypoint..."
podman run --rm --entrypoint /bin/bash localhost/openplc_official:v3 \
    -c "ls -la /workdir/start_openplc.sh" \
    || { echo "[!] start_openplc.sh missing — image broken. Aborting."; exit 1; }

# ─────────────────────────────────────────────
# 3. Launch container
# ─────────────────────────────────────────────

# Allow rootless Podman to bind privileged ports (< 1024)
echo "[*] Lowering unprivileged port start for Modbus/502 binding..."
if [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)" -gt 502 ]; then
    sudo sysctl -w net.ipv4.ip_unprivileged_port_start=502 || {
        echo "[!] Could not set ip_unprivileged_port_start. Using host port 5020 instead."
        MODBUS_PORT=5020
    }
fi
MODBUS_PORT=${MODBUS_PORT:-502}

echo "[*] Starting OpenPLC Runtime container (Shadow Actual)..."
podman run -d \
    --name openplc_shadow \
    -p 8080:8080 \
    -p ${MODBUS_PORT}:502 \
    openplc_official:v3

echo "[*] Waiting 15 seconds for runtime initialization..."
sleep 15

# Clean up temporary setup folder
rm -rf "$SETUP_TMP"

# ─────────────────────────────────────────────
# 5. Final status
# ─────────────────────────────────────────────
echo ""
echo "[+] ──────────────────────────────────────────────"
echo "[+]  Shadow Garden Deployment Complete"
echo "[+] ──────────────────────────────────────────────"
echo "[+]  Web Dashboard : http://localhost:8080"
echo "[+]  Modbus TCP    : localhost:${MODBUS_PORT:-502}"
echo "[+]  Credentials   : openplc / openplc"
echo "[+]  Active PLC    : None (Ready for baseline program upload)"
echo "[+] ──────────────────────────────────────────────"
echo ""
echo "[*] To configure and inject your code:"
echo "    1. Create your own baseline.st file to configure the three critical feeders:"
echo "       - FEEDER_1_CMD at %QX0.0 (set to TRUE)"
echo "       - FEEDER_2_CMD at %QX0.1 (set to TRUE)"
echo "       - FEEDER_3_CMD at %QX0.2 (set to TRUE)"
echo "    2. Upload baseline.st to the OpenPLC Web UI (http://localhost:8080) and compile it to establish a clean state."
echo "    3. Edit baseline.st to implement your timer logic and save it as malicious.st"
echo "    4. Upload malicious.st via the Web UI and compile it, OR deploy it via the CLI/API."