#!/usr/bin/env bash
# setup.sh - Red Module Setup Script

echo "[+] Cleaning up any existing Modbus server processes..."
pkill -f modbus_server 2>/dev/null || true

# Kill any process listening on port 5020 to ensure we can bind successfully
if command -v lsof >/dev/null 2>&1; then
    PID=$(lsof -t -i:5020 2>/dev/null || true)
    if [ ! -z "$PID" ]; then
        echo "[+] Killing process $PID listening on port 5020..."
        kill -9 $PID 2>/dev/null || true
    fi
fi

echo "[+] Installing required dependencies..."
apt-get update -y || true
apt-get install -y python3-pip nmap netcat-openbsd lsof || true
pip3 install pymodbus==3.5.2 --break-system-packages || pip3 install pymodbus==3.5.2 || pip install pymodbus==3.5.2 || true

echo "[+] Running central challenge update script..."
python3 ../update_challenge.py

echo "[+] Creating Whitelist document (whitelist.txt)..."
echo "192.168.1.10" > whitelist.txt

echo "[+] Creating Process Description document (process_description.txt)..."
cat << 'EOF' > process_description.txt
TRANSFORMER SUBSTATION - PROCESS DESCRIPTION
--------------------------------------------
This system monitors a critical distribution transformer.
Process Variables:
- Cooling Fan State: Toggles ON/OFF based on thermal load.
- Breaker Position: Indicates if the primary circuit is OPEN or CLOSED.
- Transformer Load: Measured in Megawatts (MW). Fluctuates continuously between 50 MW and 150 MW.
- Oil Temperature: Measured in Celsius (C). Drifts slowly between 40 C and 90 C.

Note: Decoy sensors are present. Address mapping is strictly confidential.
EOF

# Ensure modbus_server script is executable
chmod +x modbus_server

echo "[+] Starting Modbus TCP Server in background on port 5020..."
nohup ./modbus_server > /dev/null 2> server.err &
sleep 2

echo "[+] Setup Complete."