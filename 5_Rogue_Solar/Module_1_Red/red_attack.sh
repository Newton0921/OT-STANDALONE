#!/bin/bash
# red_attack.sh - Shell wrapper for the Python attack script
# Connects to the misconfigured MQTT broker and injects a forged value.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
python3 "${SCRIPT_DIR}/red_attack.py" "$@"#!/bin/bash
# setup.sh - Red Module
# Sets up the MQTT broker, legitimate publisher, and energy dashboard.
# No python scripts (.py) are created on disk; everything runs in bash (.sh).

SKIP_INSTALL=false
if [ "$1" = "--no-install" ]; then
    SKIP_INSTALL=true
fi

if [ "$SKIP_INSTALL" = false ]; then
    echo "[*] Installing dependencies..."
    # Update package lists and install mosquitto, mosquitto-clients, flask, and paho-mqtt natively
    echo "arch" | sudo -S apt-get update
    echo "arch" | sudo -S apt-get install -y mosquitto mosquitto-clients docker.io nmap python3-flask python3-paho-mqtt
else
    echo "[*] Skipping dependency installation as requested."
fi

echo "[*] Creating workspace..."
mkdir -p /tmp/mqtt_lab/config /tmp/mqtt_lab/log
touch /tmp/mqtt_lab/log/mosquitto.log
touch /tmp/mqtt_lab/log/ground_truth.log

# Determine if Docker is running and available
DOCKER_RUNNING=false
if command -v docker &> /dev/null; then
    if sudo docker ps &> /dev/null; then
        DOCKER_RUNNING=true
    fi
fi

# Always stop native system service and kill any local mosquitto to free port 1883
echo "[*] Stopping any running native mosquitto broker..."
echo "arch" | sudo -S systemctl stop mosquitto 2>/dev/null || true
sudo killall mosquitto 2>/dev/null || true

# Create Mosquitto Configuration
if [ "$DOCKER_RUNNING" = true ]; then
    cat << 'EOF' > /tmp/mqtt_lab/config/mosquitto.conf
listener 1883 0.0.0.0
allow_anonymous true
acl_file /mosquitto/config/acl
log_dest file /mosquitto/log/mosquitto.log
log_type all
connection_messages true
EOF
else
    cat << 'EOF' > /tmp/mqtt_lab/config/mosquitto.conf
listener 1883 0.0.0.0
allow_anonymous true
acl_file /tmp/mqtt_lab/config/acl
log_dest file /tmp/mqtt_lab/log/mosquitto.log
log_type all
connection_messages true
EOF
fi

# Create the misconfigured ACL file
# Permissive rule: allows any client to read and write to the solar topic
cat << 'EOF' > /tmp/mqtt_lab/config/acl
pattern readwrite grid/solar/site7/#
EOF

# Make everything writable
sudo chmod -R 777 /tmp/mqtt_lab

# Start Mosquitto Broker
if [ "$DOCKER_RUNNING" = true ]; then
    echo "[*] Starting Mosquitto in Docker..."
    sudo docker stop mqtt_broker 2>/dev/null || true
    sudo docker rm mqtt_broker 2>/dev/null || true
    sudo docker run -d --name mqtt_broker -p 1883:1883 \
        -v /tmp/mqtt_lab/config:/mosquitto/config \
        -v /tmp/mqtt_lab/log:/mosquitto/log \
        eclipse-mosquitto:latest
else
    echo "[!] Docker not running. Starting Mosquitto natively on host..."
    # Start custom mosquitto natively as a daemon
    sudo mosquitto -c /tmp/mqtt_lab/config/mosquitto.conf -d
fi

sleep 3 # Wait for broker to initialize

# Function to get solar curve value in bash using awk
get_solar_value() {
    local step=$1
    awk -v s="$step" 'BEGIN { printf "%.2f", 45.0 + sin(s / 10.0) * 5.0 }'
}

echo "[*] Pre-seeding logs with 15 minutes of legitimate baseline activity..."
# 90 entries at 10-second intervals = 15 minutes
base_time=$(date +%s)
start_time=$((base_time - 900))
ip_legit="192.168.10.55"

# Empty the log files first
> /tmp/mqtt_lab/log/mosquitto.log
> /tmp/mqtt_lab/log/ground_truth.log

# Write simulated baseline connection
echo "${start_time}: New client connected from ${ip_legit} as solar_publisher_site7 (p2, c1, k60)." >> /tmp/mqtt_lab/log/mosquitto.log

for i in $(seq 0 89); do
    t=$((start_time + i * 10))
    val=$(get_solar_value $i)
    len_val=${#val}
    # Simulate Mosquitto logs
    echo "${t}: Client solar_publisher_site7 PUBLISH (d0, q0, r1, m0, 'grid/solar/site7/kw', ... (${len_val} bytes))" >> /tmp/mqtt_lab/log/mosquitto.log
    echo "${t}: 	Payload: ${val}" >> /tmp/mqtt_lab/log/mosquitto.log
    
    # Write to ground truth log
    timestamp=$(date -d "@$t" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -r "$t" +"%Y-%m-%dT%H:%M:%S")
    echo "${timestamp} - ${val} kW" >> /tmp/mqtt_lab/log/ground_truth.log
done

# Create Legitimate Solar Publisher script (Python using paho-mqtt)
cat << 'EOF' > /tmp/mqtt_lab/legit_publisher.py
#!/usr/bin/env python3
import time
import math
import datetime
import paho.mqtt.client as mqtt

BROKER = "127.0.0.1"
PORT = 1883
TOPIC = "grid/solar/site7/kw"
CLIENT_ID = "solar_publisher_site7"
LOG_FILE = "/tmp/mqtt_lab/log/ground_truth.log"

def get_solar_value(step):
    return round(45.0 + math.sin(step / 10.0) * 5.0, 2)

def main():
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id=CLIENT_ID)
    except AttributeError:
        client = mqtt.Client(client_id=CLIENT_ID)
        
    client.connect(BROKER, PORT, 60)
    client.loop_start()
    
    step = 90
    while True:
        val = get_solar_value(step)
        client.publish(TOPIC, str(val), qos=0, retain=True)
        
        timestamp = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
        with open(LOG_FILE, "a") as f:
            f.write(f"{timestamp} - {val:.2f} kW\n")
            
        step += 1
        time.sleep(10)

if __name__ == "__main__":
    main()
EOF
chmod +x /tmp/mqtt_lab/legit_publisher.py

# Start the Legitimate Publisher
nohup python3 /tmp/mqtt_lab/legit_publisher.py > /tmp/mqtt_lab/log/publisher.out 2>&1 &
echo $! > /tmp/mqtt_lab/publisher.pid

# Create Web Dashboard Subscriber (Flask served inline in Bash)
cat << 'EOF' > /tmp/mqtt_lab/dashboard.sh
#!/bin/bash
# dashboard.sh
# Web-based Flask dashboard running entirely inline inside shell script

python3 -c '
import flask, paho.mqtt.client as mqtt, threading

app = flask.Flask(__name__)
current_val = "0.00"

def on_message(client, userdata, msg):
    global current_val
    current_val = msg.payload.decode()

client = mqtt.Client(client_id="dashboard_web_sub")
client.on_message = on_message
client.connect("127.0.0.1", 1883, 60)
client.subscribe("grid/solar/site7/kw")
threading.Thread(target=client.loop_forever, daemon=True).start()

@app.route("/")
def index():
    return f"""
    <html>
    <head>
        <title>Solar Telemetry Dashboard</title>
        <meta http-equiv="refresh" content="2">
        <style>
            body {{ font-family: "Segoe UI", Arial, sans-serif; background: #0f172a; color: #f8fafc; text-align: center; padding: 50px; margin: 0; }}
            .container {{ max-width: 600px; margin: 0 auto; }}
            .card {{ background: #1e293b; border: 1px solid #334155; padding: 40px; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.3); margin-top: 50px; }}
            h1 {{ color: #f59e0b; font-size: 28px; margin-bottom: 5px; }}
            p {{ color: #94a3b8; font-size: 14px; margin-top: 0; }}
            .value-box {{ margin: 30px 0; padding: 20px; background: #0f172a; border-radius: 12px; border: 1px solid #1e293b; }}
            .value {{ font-size: 56px; font-weight: 800; color: #10b981; }}
            .unit {{ font-size: 24px; color: #64748b; font-weight: 500; }}
            .status {{ font-size: 14px; font-weight: 600; color: #10b981; display: inline-flex; align-items: center; gap: 6px; }}
            .status-dot {{ width: 8px; height: 8px; background-color: #10b981; border-radius: 50%; display: inline-block; animation: pulse 2s infinite; }}
            @keyframes pulse {{
                0% {{ transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }}
                70% {{ transform: scale(1); box-shadow: 0 0 0 6px rgba(16, 185, 129, 0); }}
                100% {{ transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }}
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="card">
                <h1>Solar Telemetry Dashboard</h1>
                <p>Telemetry Topic: <code>grid/solar/site7/kw</code></p>
                <div class="value-box">
                    <span class="value">{current_val}</span>
                    <span class="unit"> kW</span>
                </div>
                <div class="status">
                    <span class="status-dot"></span> Active (Monitoring)
                </div>
            </div>
        </div>
    </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
'
EOF
chmod +x /tmp/mqtt_lab/dashboard.sh

# Start the Dashboard
nohup /tmp/mqtt_lab/dashboard.sh > /tmp/mqtt_lab/log/dashboard.out 2>&1 &
echo $! > /tmp/mqtt_lab/dashboard.pid

# Reset permissions so user can inspect everything easily
sudo chmod -R 777 /tmp/mqtt_lab

echo "[+] Red Module Setup Complete! Environment is running and exploitable."