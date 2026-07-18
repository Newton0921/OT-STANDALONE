#!/bin/bash
# Contractor Account Reuse — Red Module Setup
# Real environment: live Modbus, live Flask HMI, credential leak server, audit log
set -e

if [ "$EUID" -ne 0 ]; then echo "[-] Run as root."; exit 1; fi

echo "[*] Contractor Account Reuse — Red Module Setup"
echo "[*] Platform: Parrot OS / Ubuntu / Debian"

# ── 0. Cleanup ────────────────────────────────────────────────────────────
pkill -f "http.server 8081"   2>/dev/null || true
pkill -f "app.py"             2>/dev/null || true
pkill -f "modbus_sim.py"      2>/dev/null || true
systemctl stop scada-web.service  2>/dev/null || true
systemctl stop modbus-sim.service 2>/dev/null || true
sleep 1

# ── 1. Directories ────────────────────────────────────────────────────────
mkdir -p /opt/scada/ScadaWeb/log
mkdir -p /var/www/html/backup
mkdir -p /var/log/substation_maintenance
chmod -R 777 /opt/scada/ScadaWeb/log /var/www/html/backup /var/log/substation_maintenance

# Fix broken MS repo on Parrot OS
if [ -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
  sed -i 's/^deb/# deb/g' /etc/apt/sources.list.d/microsoft-prod.list
fi

# ── 2. Python venv ────────────────────────────────────────────────────────
echo "[*] Creating Python venv..."
python3 -m venv /opt/modbus_venv
VPIP=/opt/modbus_venv/bin/pip
VPY=/opt/modbus_venv/bin/python

$VPIP install --quiet --upgrade pip
$VPIP install --quiet pymodbus==2.5.3 flask

$VPY -c "import pymodbus; print('[+] pymodbus OK')"
$VPY -c "import flask;    print('[+] flask OK')"

# ── 3. Install Python scripts ─────────────────────────────────────────────
mkdir -p /opt/scada/ScadaWeb

cat << 'PYEOF' > /usr/local/bin/modbus_sim.py
import collections
# Patch deprecated collections aliases for Python 3.10+ compatibility in pymodbus 2.5.3
try:
    import collections.abc
    collections.MutableMapping = collections.abc.MutableMapping
    collections.Mapping = collections.abc.Mapping
    collections.Sequence = collections.abc.Sequence
    collections.Iterable = collections.abc.Iterable
    collections.Container = collections.abc.Container
    collections.Callable = collections.abc.Callable
except AttributeError:
    pass

from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusSlaveContext,
    ModbusServerContext
)

store = ModbusSlaveContext(
    di=ModbusSequentialDataBlock(0, [17]*100),
    co=ModbusSequentialDataBlock(0, [17]*100),
    hr=ModbusSequentialDataBlock(0, [17]*100),
    ir=ModbusSequentialDataBlock(0, [17]*100))

context = ModbusServerContext(slaves=store, single=True)
print("[*] Modbus simulator listening on 127.0.0.1:5020")
StartTcpServer(context, address=("127.0.0.1", 5020))
PYEOF
chmod +x /usr/local/bin/modbus_sim.py

cat << 'PYEOF' > /opt/scada/ScadaWeb/app.py
from flask import Flask, request, render_template_string, redirect, session, abort, jsonify, has_request_context
import datetime
import os

app = Flask(__name__)
app.secret_key = os.urandom(24)

USERS = {
    "Operator1":        "Op3r@t0r!",
    "Engineer1":        "Eng1n33r#",
    "contractor_maint": "Welcome123"   # leaked in maint_notes_112.json
}

LOG_FILE = "/opt/scada/ScadaWeb/log/ScadaWeb.log"

def log_event(msg):
    ts = None
    if has_request_context():
        ts = request.headers.get("X-Forwarded-Time")
    if not ts:
        ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(f"[{ts}] {msg}\n")

# CSS Design System (Glassmorphic dark mode, neon grid theme)
SHARED_CSS = """
:root {
  --bg-primary: #080c14;
  --bg-secondary: #0f172a;
  --bg-card: rgba(30, 41, 59, 0.7);
  --accent-color: #00ff88;
  --accent-blue: #00d9ff;
  --accent-warning: #f59e0b;
  --accent-danger: #ef4444;
  --text-main: #f1f5f9;
  --text-muted: #94a3b8;
  --border-color: rgba(51, 65, 85, 0.5);
  --glow-shadow: 0 0 15px rgba(0, 255, 136, 0.2);
}

body {
  background-color: var(--bg-primary);
  color: var(--text-main);
  font-family: 'Courier New', Courier, monospace;
  margin: 0;
  padding: 0;
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100vw;
  height: 100vh;
  background: radial-gradient(circle at center, #1e293b 0%, #080c14 100%);
}

.login-card {
  background: var(--bg-card);
  backdrop-filter: blur(10px);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 40px;
  width: 360px;
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.5);
  text-align: center;
}

.login-card h2 {
  color: var(--accent-color);
  margin-bottom: 30px;
  letter-spacing: 2px;
  font-size: 24px;
  text-shadow: 0 0 10px rgba(0, 255, 136, 0.4);
}

.input-field {
  width: 100%;
  padding: 12px;
  margin-bottom: 20px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  color: var(--text-main);
  font-family: inherit;
  box-sizing: border-box;
}

.input-field:focus {
  border-color: var(--accent-color);
  outline: none;
  box-shadow: var(--glow-shadow);
}

.login-btn {
  width: 100%;
  padding: 12px;
  background: var(--accent-color);
  color: #022c22;
  border: none;
  border-radius: 6px;
  font-weight: bold;
  cursor: pointer;
  letter-spacing: 1px;
  transition: all 0.3s;
}

.login-btn:hover {
  background: #059669;
  box-shadow: var(--glow-shadow);
}

.error-msg {
  color: var(--accent-danger);
  margin-bottom: 15px;
  font-size: 13px;
}

/* Dashboard Layout */
.sidebar {
  width: 280px;
  background-color: var(--bg-secondary);
  border-right: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 20px;
  box-sizing: border-box;
}

.sidebar-header {
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 15px;
  margin-bottom: 20px;
}

.sidebar-header h3 {
  color: var(--accent-color);
  margin: 0;
  letter-spacing: 1px;
}

.sidebar-nav {
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex-grow: 1;
}

.nav-item {
  padding: 12px 15px;
  color: var(--text-muted);
  text-decoration: none;
  border-radius: 6px;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid transparent;
}

.nav-item:hover {
  background-color: rgba(30, 41, 59, 0.5);
  color: var(--text-main);
}

.nav-item.active {
  background-color: rgba(0, 255, 136, 0.1);
  border-color: rgba(0, 255, 136, 0.3);
  color: var(--accent-color);
}

.nav-item.restricted {
  border-color: rgba(239, 68, 68, 0.2);
  color: #f87171;
}

.nav-item.restricted:hover {
  background-color: rgba(239, 68, 68, 0.1);
}

.main-content {
  flex-grow: 1;
  padding: 30px;
  overflow-y: auto;
  box-sizing: border-box;
}

.header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 15px;
  margin-bottom: 25px;
}

.header-bar h2 {
  margin: 0;
}

.user-tag {
  color: var(--accent-blue);
  font-weight: bold;
}

.logout-btn {
  color: var(--accent-danger);
  text-decoration: none;
  border: 1px solid var(--accent-danger);
  padding: 6px 12px;
  border-radius: 4px;
  transition: all 0.2s;
}

.logout-btn:hover {
  background-color: var(--accent-danger);
  color: white;
}

/* Widgets */
.grid-container {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.widget {
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 20px;
}

.widget h4 {
  margin-top: 0;
  color: var(--text-muted);
  letter-spacing: 1px;
}

.widget-value {
  font-size: 24px;
  font-weight: bold;
  color: var(--accent-color);
  text-shadow: 0 0 10px rgba(0, 255, 136, 0.2);
}

.table-container {
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 30px;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  padding: 12px 15px;
  text-align: left;
  border-bottom: 1px solid var(--border-color);
}

th {
  color: var(--accent-blue);
  font-weight: bold;
}

.status-indicator {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 8px;
}

.status-indicator.active {
  background-color: var(--accent-color);
  box-shadow: 0 0 8px var(--accent-color);
}

.status-indicator.inactive {
  background-color: var(--accent-danger);
  box-shadow: 0 0 8px var(--accent-danger);
}

/* Flag specific */
.flag-card {
  background: rgba(239, 68, 68, 0.05);
  border: 2px dashed var(--accent-danger);
  border-radius: 8px;
  padding: 25px;
  margin-top: 30px;
  text-align: center;
  box-shadow: 0 0 20px rgba(239, 68, 68, 0.1);
}

.flag-title {
  color: var(--accent-danger);
  font-size: 18px;
  font-weight: bold;
  margin-bottom: 10px;
}

.flag-value {
  font-size: 22px;
  font-weight: bold;
  color: var(--text-main);
  background: rgba(15, 23, 42, 0.8);
  padding: 10px;
  border-radius: 4px;
  display: inline-block;
  letter-spacing: 2px;
  border: 1px solid rgba(239, 68, 68, 0.3);
}

/* Schematic */
.schematic-box {
  background: #020617;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 20px;
  text-align: center;
  margin-top: 20px;
}
"""

LOGIN_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
    <title>Rapid SCADA Webstation - Control Room</title>
    <style>
        """ + SHARED_CSS + """
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-card">
            <h2>⚡ RAPID SCADA 6</h2>
            <p style="color: var(--text-muted); font-size: 12px; margin-bottom: 25px;">Substation Operator Interface</p>
            {% if error %}
                <div class="error-msg">⚠ {{ error }}</div>
            {% endif %}
            <form method="POST">
                <input class="input-field" name="username" placeholder="Username" required autocomplete="off">
                <input class="input-field" name="password" type="password" placeholder="Password" required>
                <button class="login-btn" type="submit">ESTABLISH SESSION</button>
            </form>
            <p style="color: #334155; font-size: 10px; margin-top: 30px;">Security System Level: ICS-Level-3</p>
        </div>
    </div>
</body>
</html>"""

LAYOUT_START = """<!DOCTYPE html>
<html>
<head>
    <title>Rapid SCADA - Control Dashboard</title>
    <style>
        """ + SHARED_CSS + """
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-nav">
            <div class="sidebar-header">
                <h3>⚡ SCADA CONTROL</h3>
                <span style="font-size: 10px; color: var(--text-muted);">Station ID: SUB_115K_HV</span>
            </div>
            <a href="/dashboard" class="nav-item {% if active_page == 'dashboard' %}active{% endif %}">
                <span>📊</span> Main Dashboard
            </a>
            <a href="/diagnostics" class="nav-item {% if active_page == 'diagnostics' %}active{% endif %}">
                <span>⚙</span> Diagnostics
            </a>
            {% if is_contractor %}
            <a href="/Substation_High_Voltage_Feeder" class="nav-item restricted {% if active_page == 'restricted' %}active{% endif %}">
                <span>🚨</span> Restricted Feeder
            </a>
            {% endif %}
        </div>
        <div style="border-top: 1px solid var(--border-color); padding-top: 15px;">
            <p style="font-size: 11px; margin: 0 0 10px 0; color: var(--text-muted);">Session: <span class="user-tag">{{ user }}</span></p>
            <a href="/logout" class="logout-btn" style="display: block; text-align: center;">TERMINATE SESSION</a>
        </div>
    </div>
    <div class="main-content">
        <div class="header-bar">
            <h2>{{ title }}</h2>
            <div style="font-size: 12px; color: var(--text-muted);">System Time: {{ ts }}</div>
        </div>
"""

LAYOUT_END = """
    </div>
</body>
</html>"""

DASHBOARD_CONTENT = """
        <div class="grid-container">
            <div class="widget">
                <h4>GRID FREQUENCY</h4>
                <div class="widget-value">50.02 Hz</div>
            </div>
            <div class="widget">
                <h4>AVERAGE VOLTAGE</h4>
                <div class="widget-value" style="color: var(--accent-blue);">115.4 kV</div>
            </div>
            <div class="widget">
                <h4>TOTAL LOAD</h4>
                <div class="widget-value" style="color: var(--accent-warning);">42.8 MW</div>
            </div>
        </div>

        <div class="table-container">
            <h3 style="margin-top: 0; color: var(--accent-blue);">Feeder Instrumentation Telemetry</h3>
            <table>
                <thead>
                    <tr>
                        <th>Feeder Instrument</th>
                        <th>Register/Coil</th>
                        <th>Telemetry Value</th>
                        <th>Operational Status</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>FEEDER_1_CTRL</td>
                        <td>Coil QX0.0</td>
                        <td>1 (TRUE)</td>
                        <td><span class="status-indicator active"></span>ACTIVE</td>
                    </tr>
                    <tr>
                        <td>FEEDER_2_CTRL</td>
                        <td>Coil QX0.1</td>
                        <td>1 (TRUE)</td>
                        <td><span class="status-indicator active"></span>ACTIVE</td>
                    </tr>
                    <tr>
                        <td>FEEDER_3_CTRL</td>
                        <td>Coil QX0.2</td>
                        <td>1 (TRUE)</td>
                        <td><span class="status-indicator active"></span>ACTIVE</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="table-container">
            <h3 style="margin-top: 0; color: var(--text-muted);">Baseline Access Logs (Cached)</h3>
            <table>
                <thead>
                    <tr>
                        <th>Time</th>
                        <th>User</th>
                        <th>Source IP</th>
                        <th>Action Performed</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>08:00:12</td>
                        <td>Operator1</td>
                        <td>192.168.1.50</td>
                        <td>Login successful</td>
                    </tr>
                    <tr>
                        <td>09:15:00</td>
                        <td>Engineer1</td>
                        <td>192.168.1.51</td>
                        <td>Login successful</td>
                    </tr>
                </tbody>
            </table>
        </div>
"""

DIAGNOSTICS_CONTENT = """
        <div class="table-container">
            <h3 style="margin-top: 0; color: var(--accent-blue);">System Node Diagnostics</h3>
            <table style="width: 100%">
                <tr>
                    <td><b>Node Hostname</b></td>
                    <td>substation-gw-12.local</td>
                </tr>
                <tr>
                    <td><b>Operating System</b></td>
                    <td>Linux (Debian-based Substation Gateway)</td>
                </tr>
                <tr>
                    <td><b>Rapid SCADA Webstation</b></td>
                    <td>v6.0.0 (Mock Deployment)</td>
                </tr>
                <tr>
                    <td><b>Modbus Bridge</b></td>
                    <td>Connected to 127.0.0.1:5020 (Status: <span style="color: var(--accent-color);">ONLINE</span>)</td>
                </tr>
                <tr>
                    <td><b>Database Instance</b></td>
                    <td>SQLite Local Cache (Status: <span style="color: var(--accent-color);">SYNCED</span>)</td>
                </tr>
            </table>
        </div>
"""

RESTRICTED_CONTENT = """
        {% if breaker_tripped %}
        <div class="flag-card">
            <div class="flag-title">🔑 CRITICAL ARTIFACT RECOVERED</div>
            <div class="flag-value">FLAG{contractor_access_not_revoked_9a38f}</div>
            <p style="color: var(--text-muted); font-size: 11px; margin-top: 10px; margin-bottom: 0;">
                Valid account credentials retained after contractor maintenance contract closure.
            </p>
        </div>
        {% else %}
        <div class="flag-card" style="border-color: var(--accent-warning); background: rgba(245, 158, 11, 0.1);">
            <div class="flag-title" style="color: var(--accent-warning);">🔒 CRITICAL ARTIFACT LOCKED</div>
            <div class="flag-value" style="font-family: monospace; font-size: 14px; color: var(--text-muted);">
                [STATUS: BREAKER CLOSED - Flag payload locked in register memory]
            </div>
            <p style="color: var(--text-muted); font-size: 11px; margin-top: 10px; margin-bottom: 0;">
                To retrieve the flag, dispatch a command to TRIP the High-Voltage Feeder Breaker.
            </p>
        </div>
        {% endif %}

        <div class="schematic-box">
            <h3 style="color: var(--accent-danger); margin-top: 0;">HIGH-VOLTAGE FEEDER SINGLE LINE SCHEMATIC</h3>
            
            <!-- Beautiful interactive SVG substation diagram -->
            <svg width="400" height="200" style="background: #020617; border-radius: 4px; padding: 10px;">
                <!-- Busbar -->
                <line x1="50" y1="50" x2="350" y1="50" stroke="#f59e0b" stroke-width="4" />
                <text x="50" y="40" fill="#f59e0b" font-size="10">115kV BUSBAR A</text>

                <!-- Feeder line -->
                <line x1="200" y1="50" x2="200" y1="100" stroke="{% if breaker_tripped %}#ef4444{% else %}#00ff88{% endif %}" stroke-width="2" id="line1" />
                
                <!-- Breaker Box (Interactive) -->
                <rect x="180" y="80" width="40" height="40" fill="#1e293b" stroke="{% if breaker_tripped %}#ef4444{% else %}#00ff88{% endif %}" stroke-width="2" id="breakerBox" />
                <text x="189" y="104" fill="{% if breaker_tripped %}#ef4444{% else %}#00ff88{% endif %}" font-size="10" font-weight="bold" id="breakerStatus">{% if breaker_tripped %}OFF{% else %}ON{% endif %}</text>
                
                <!-- Lower line -->
                <line x1="200" y1="120" x2="200" y1="170" stroke="{% if breaker_tripped %}#ef4444{% else %}#00ff88{% endif %}" stroke-width="2" id="line2" />
                
                <!-- Transformer / Load -->
                <circle cx="200" cy="170" r="15" fill="none" stroke="#00d9ff" stroke-width="2" />
                <circle cx="200" cy="180" r="15" fill="none" stroke="#00d9ff" stroke-width="2" />
                <text x="225" y="178" fill="#00d9ff" font-size="10">TR-882 (CLOSED)</text>
            </svg>
        </div>
"""

@app.route("/", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        u = request.form.get("username", "").strip()
        p = request.form.get("password", "")
        ip = request.headers.get("X-Forwarded-For", request.remote_addr)
        if u in USERS and USERS[u] == p:
            session["user"] = u
            session["is_contractor"] = (u == "contractor_maint")
            log_event(f"INF [{u}] Login successful from {ip}")
            return redirect("/dashboard")
        log_event(f"WRN [{u}] FAILED login attempt from {ip}")
        error = "Invalid credentials"
    return render_template_string(LOGIN_TEMPLATE, error=error)


@app.route("/dashboard")
def dashboard():
    if "user" not in session:
        return redirect("/")
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    title = "⚡ Main Substation Dashboard"
    html = LAYOUT_START + DASHBOARD_CONTENT + LAYOUT_END
    return render_template_string(html, 
                                  user=session["user"], 
                                  is_contractor=session.get("is_contractor", False),
                                  ts=ts, 
                                  title=title, 
                                  active_page="dashboard")

@app.route("/diagnostics")
def diagnostics():
    if "user" not in session:
        return redirect("/")
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    title = "⚙ Gateway Diagnostics"
    html = LAYOUT_START + DIAGNOSTICS_CONTENT + LAYOUT_END
    return render_template_string(html, 
                                  user=session["user"], 
                                  is_contractor=session.get("is_contractor", False),
                                  ts=ts, 
                                  title=title, 
                                  active_page="diagnostics")

@app.route("/Substation_High_Voltage_Feeder")
def restricted_view():
    if "user" not in session:
        return redirect("/")
    ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    if not session.get("is_contractor", False):
        log_event(f"WRN [{session['user']}] UNAUTHORIZED access attempt to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from {ip}")
        abort(403)
    
    # Read breaker status from Modbus
    telem = get_modbus_telemetry()
    breaker_tripped = (telem["breaker"] == "OPEN")
    
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    title = "🚨 Restricted Substation Feeder (ViewID: 102)"
    log_event(f"INF [{session['user']}] Access to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from {ip}")
    html = LAYOUT_START + RESTRICTED_CONTENT + LAYOUT_END
    return render_template_string(html, 
                                  user=session["user"], 
                                  is_contractor=True,
                                  ts=ts, 
                                  title=title, 
                                  active_page="restricted",
                                  breaker_tripped=breaker_tripped)

@app.route("/api/breaker/trip", methods=["POST"])
def breaker_trip():
    if "user" not in session or not session.get("is_contractor", False):
        return jsonify({"error": "Unauthorized"}), 403
    work_order = None
    if request.is_json:
        work_order = request.json.get("work_order")
    else:
        work_order = request.form.get("work_order") or request.headers.get("X-Work-Order")
    if work_order != "882":
        return jsonify({"error": "Command rejected: Invalid or missing Work Order reference"}), 400
    
    # Require validation of API command signature in X-Signature header
    signature = request.headers.get("X-Signature")
    import hashlib
    expected_str = f"{session['user']}:{work_order}:{USERS[session['user']]}"
    expected_sig = hashlib.sha256(expected_str.encode()).hexdigest()
    if signature != expected_sig:
        return jsonify({"error": "Command rejected: Invalid or missing API signature in X-Signature header"}), 400

    ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    log_event(f"INF [{session['user']}] Dispatched TRIP BREAKER command (WO: {work_order}) from {ip}")
    try:
        from pymodbus.client.sync import ModbusTcpClient
        client = ModbusTcpClient('127.0.0.1', port=5020)
        if client.connect():
            # write 0 to holding register 4
            client.write_register(4, 0)
            client.close()
            return jsonify({"status": "success", "breaker": "OPEN"})
        return jsonify({"error": "Could not connect to Modbus simulator"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/breaker/close", methods=["POST"])
def breaker_close():
    if "user" not in session or not session.get("is_contractor", False):
        return jsonify({"error": "Unauthorized"}), 403
    work_order = None
    if request.is_json:
        work_order = request.json.get("work_order")
    else:
        work_order = request.form.get("work_order") or request.headers.get("X-Work-Order")
    if work_order != "882":
        return jsonify({"error": "Command rejected: Invalid or missing Work Order reference"}), 400

    # Require validation of API command signature in X-Signature header
    signature = request.headers.get("X-Signature")
    import hashlib
    expected_str = f"{session['user']}:{work_order}:{USERS[session['user']]}"
    expected_sig = hashlib.sha256(expected_str.encode()).hexdigest()
    if signature != expected_sig:
        return jsonify({"error": "Command rejected: Invalid or missing API signature in X-Signature header"}), 400

    ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    log_event(f"INF [{session['user']}] Dispatched CLOSE BREAKER command (WO: {work_order}) from {ip}")
    try:
        from pymodbus.client.sync import ModbusTcpClient
        client = ModbusTcpClient('127.0.0.1', port=5020)
        if client.connect():
            # write 1 to holding register 4
            client.write_register(4, 1)
            client.close()
            return jsonify({"status": "success", "breaker": "CLOSED"})
        return jsonify({"error": "Could not connect to Modbus simulator"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/logout")
def logout():
    u = session.pop("user", "unknown")
    session.pop("is_contractor", None)
    ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    log_event(f"INF [{u}] Logged out from {ip}")
    return redirect("/")


def get_modbus_telemetry():
    data = {
        "voltage_kv": 115.4,
        "frequency_hz": 50.02,
        "load_mw": 42.8,
        "current_a": 215.3,
        "breaker": "CLOSED",
        "source": "Modbus Sim (Fallback)"
    }
    try:
        from pymodbus.client.sync import ModbusTcpClient
        client = ModbusTcpClient('127.0.0.1', port=5020)
        if client.connect():
            rr = client.read_holding_registers(0, 5)
            if not rr.isError():
                v = rr.registers[0]
                f = rr.registers[1]
                l = rr.registers[2]
                c = rr.registers[3]
                b = rr.registers[4]
                data["voltage_kv"] = round(110.0 + (v / 10.0), 2)
                data["frequency_hz"] = round(50.0 + (f / 100.0), 2)
                data["load_mw"] = round(10.0 + (l / 2.0), 2)
                data["current_a"] = round(100.0 + c, 2)
                data["breaker"] = "CLOSED" if b > 0 else "OPEN"
                data["source"] = "Modbus Server (127.0.0.1:5020)"
            client.close()
    except Exception:
        pass
    return data

@app.route("/api/telemetry")
def api_telemetry():
    if "user" not in session:
        return jsonify({"error": "Unauthorized"}), 401
    return jsonify(get_modbus_telemetry())

if __name__ == "__main__":
    print("[*] SCADA Webstation listening on 0.0.0.0:10008")
    app.run(host="0.0.0.0", port=10008, debug=False)
PYEOF


# ── 4. Systemd — Modbus Simulator ─────────────────────────────────────────
cat > /etc/systemd/system/modbus-sim.service << SVCEOF
[Unit]
Description=Modbus Feeder Simulator (Live Telemetry)
After=network.target

[Service]
ExecStart=${VPY} /usr/local/bin/modbus_sim.py
Restart=on-failure
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SVCEOF

# ── 5. Systemd — SCADA HMI ────────────────────────────────────────────────
cat > /etc/systemd/system/scada-web.service << SVCEOF
[Unit]
Description=SCADA Webstation HMI
After=network.target modbus-sim.service

[Service]
ExecStart=${VPY} /opt/scada/ScadaWeb/app.py
Restart=on-failure
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SVCEOF

# ── 6. Credential Leak ────────────────────────────────────────────────────
echo "[*] Planting credential leak artifact..."
cat > /var/www/html/backup/maint_notes_112.json << 'JSONEOF'
{
  "work_order": "882",
  "status": "CLOSED",
  "completion_date": "2026-06-15",
  "technician": "contractor_maint",
  "temp_access_token_hash": "133987b0b6ad0c01fc0ccbdae1b95449",
  "notes": "HV Feeder maintenance complete. Temporary password generated and stored as MD5 hash per security policy. Awaiting AD de-provisioning.",
  "review_url": "http://127.0.0.1:10008"
}
JSONEOF

# ── 7. Seed baseline audit log ────────────────────────────────────────────
echo "[*] Seeding baseline audit log..."
cat > /opt/scada/ScadaWeb/log/ScadaWeb.log << 'LOGEOF'
[2026-06-17 08:00:12] INF [Operator1] Login successful from 192.168.1.50
[2026-06-17 08:05:33] INF [Operator1] Access to view 'Main_Dashboard' (ViewID:1) from 192.168.1.50
[2026-06-17 09:15:00] INF [Engineer1] Login successful from 192.168.1.51
[2026-06-17 09:16:10] INF [Engineer1] Access to view 'System_Diagnostics' (ViewID:99) from 192.168.1.51
[2026-06-17 14:30:01] INF [Operator1] Access to view 'Main_Dashboard' (ViewID:1) from 192.168.1.50
[2026-06-17 14:32:45] INF [Operator1] Logout from 192.168.1.50
[2026-06-17 17:05:22] INF [Engineer1] Logout from 192.168.1.51
LOGEOF

# ── 8. Closed Work Order (Blue forensic artifact) ─────────────────────────
cat > /var/log/substation_maintenance/work_order_882_CLOSED.txt << 'WOEOF'
WORK ORDER: 882
SYSTEM: Substation High Voltage Feeder (SUB_115K_HV)
TECHNICIAN: contractor_maint
ROLE: Maintenance Contractor (3rd Party)
STATUS: CLOSED
START_DATE: 2026-06-13
END_DATE: 2026-06-15
NOTES: Physical HV feeder inspection complete. System returned to operational status.
AD_DEPROVISIONING: PENDING — contractor_maint account NOT yet disabled.
WOEOF

# ── 9. Start services ─────────────────────────────────────────────────────
echo "[*] Starting services..."
systemctl daemon-reload
systemctl enable --now modbus-sim.service
sleep 2
systemctl enable --now scada-web.service
sleep 2

# Credential leak HTTP server (port 8081)
nohup $VPY -m http.server 8081 \
    --directory /var/www/html > /tmp/leak_server.log 2>&1 &
echo $! > /tmp/leak_server.pid
sleep 2

# ── 10. Health checks ─────────────────────────────────────────────────────
echo "[*] Running health checks..."
SCADA_UP=false; LEAK_UP=false; MODBUS_UP=false

systemctl is-active --quiet scada-web.service  && SCADA_UP=true
systemctl is-active --quiet modbus-sim.service && MODBUS_UP=true
curl -sf -o /dev/null "http://127.0.0.1:8081/backup/maint_notes_112.json" && LEAK_UP=true

echo ""
echo "[+] ─────────────────────────────────────────────────"
echo "[+]  RED MODULE SETUP COMPLETE"
echo "[+] ─────────────────────────────────────────────────"
printf "[+]  SCADA HMI       : http://127.0.0.1:10008  [%s]\n" \
    "$($SCADA_UP  && echo '✓ UP' || echo '✗ DOWN')"
printf "[+]  Credential Leak : http://127.0.0.1:8081/backup/maint_notes_112.json  [%s]\n" \
    "$($LEAK_UP   && echo '✓ UP' || echo '✗ DOWN')"
printf "[+]  Modbus Sim      : 127.0.0.1:5020  [%s]\n" \
    "$($MODBUS_UP && echo '✓ UP' || echo '✗ DOWN')"
echo "[+]  Audit Log       : /opt/scada/ScadaWeb/log/ScadaWeb.log"
echo "[+]  Score Log       : /opt/scada/ScadaWeb/log/score.log"
echo "[+] ─────────────────────────────────────────────────"
echo "[+]  RED ATTACK CHAIN:"
echo "[+]  Step 1 → Enumerate: GET http://127.0.0.1:8081/backup/maint_notes_112.json"
echo "[+]  Step 2 → Extract creds: contractor_maint : Welcome123"
echo "[+]  Step 3 → Login SCADA: http://127.0.0.1:10008"
echo "[+]  Step 4 → Access restricted view: /Substation_High_Voltage_Feeder"
echo "[+]  Step 5 → Capture flag. Audit trail auto-written to log."
echo "[+] ─────────────────────────────────────────────────"