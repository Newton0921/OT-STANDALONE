#!/usr/bin/env bash
# setup.sh - Blue Module Setup Script

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

echo "[+] Generating Modbus Server Script..."
cat << 'EOF' > modbus_server
#!/usr/bin/env python3
import asyncio
import logging
import random
import sys
import os
import json
from datetime import datetime

# Detect version compatibility
try:
    from pymodbus.server.server import ModbusTcpServer
    from pymodbus.server.requesthandler import ServerRequestHandler
    USE_LEGACY_HANDLER = False
except ImportError:
    from pymodbus.server.async_io import ModbusTcpServer, ModbusServerRequestHandler as ServerRequestHandler
    USE_LEGACY_HANDLER = True

from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext

# Locate configuration file
def load_config():
    paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), ".register_map.json"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".register_map.json"),
        "/home/newton/Hacktify/3_Transformer-Register-Baseline-Reconstruction/.register_map.json"
    ]
    for p in paths:
        if os.path.exists(p):
            with open(p, "r") as f:
                return json.load(f)
    raise FileNotFoundError("Configuration file .register_map.json not found!")

if USE_LEGACY_HANDLER:
    class LoggingRequestHandler(ServerRequestHandler):
        def execute(self, request, *addr):
            client_ip = "Unknown"
            if hasattr(self, 'transport') and self.transport:
                peername = self.transport.get_extra_info('peername')
                if peername:
                    client_ip = peername[0]
                    
            fc = request.function_code
            addr_val = request.address
            qty = getattr(request, 'count', 1)
            
            result = "Success"
            try:
                super().execute(request, *addr)
            except Exception as e:
                result = f"Error: {str(e)}"
                raise e
            finally:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_line = f"{timestamp} - Client: {client_ip} - FC: {fc} - Addr: {addr_val} - Qty: {qty} - Result: {result}\n"
                try:
                    with open("./modbus_server.log", "a") as f:
                        f.write(log_line)
                except Exception:
                    pass

    class LoggingModbusTcpServer(ModbusTcpServer):
        def callback_new_connection(self):
            return LoggingRequestHandler(self)
else:
    class LoggingRequestHandler(ServerRequestHandler):
        async def handle_request(self):
            peername = self.transport.get_extra_info('peername') if self.transport else None
            client_ip = peername[0] if peername else "Unknown"
            
            request = self.last_pdu
            if request:
                fc = request.function_code
                addr_val = request.address
                qty = getattr(request, 'count', 1)
            else:
                fc, addr_val, qty = "Unknown", "Unknown", "Unknown"
                
            result = "Success"
            try:
                await super().handle_request()
            except Exception as e:
                result = f"Error: {str(e)}"
                raise e
            finally:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_line = f"{timestamp} - Client: {client_ip} - FC: {fc} - Addr: {addr_val} - Qty: {qty} - Result: {result}\n"
                try:
                    with open("./modbus_server.log", "a") as f:
                        f.write(log_line)
                except Exception:
                    pass

    class LoggingModbusTcpServer(ModbusTcpServer):
        def callback_new_connection(self):
            if self.trace_connect:
                self.trace_connect(True)
            return LoggingRequestHandler(
                self,
                self.trace_packet,
                self.trace_pdu,
                self.trace_connect
            )

async def update_registers(context, config):
    load_addr = config["LoadAddr"]
    temp_addr = config["TempAddr"]
    fan_addr = config["FanAddr"]
    breaker_addr = config["BreakerAddr"]
    
    # State variables for physical simulation
    current_load = 100.0
    current_temp = 65.0
    fan_state = 0
    breaker_state = 1
    trip_timer = 0
    
    while True:
        try:
            if breaker_state == 1:
                # Normal operation: Load drifts slowly
                current_load = max(50.0, min(150.0, current_load + random.uniform(-4.0, 4.0)))
                
                # Check for overload trip condition (Load > 140 MW)
                if current_load > 140.0 and random.random() < 0.15:
                    breaker_state = 0
                    current_load = 0.0
                    trip_timer = 5 # 10 seconds trip duration
            else:
                # Tripped state: cooldown, trip timer decrements
                current_load = 0.0
                trip_timer -= 1
                if trip_timer <= 0:
                    breaker_state = 1 # Autoreclose
                    current_load = 80.0
            
            # Thermal Model for Temperature
            temp_override = context[0].getValues(3, temp_addr, count=1)
            if temp_override and temp_override[0] == 0:
                current_temp = 0.0
            else:
                target_temp = 40.0 + (current_load - 50.0) * 0.4
                if fan_state == 1:
                    target_temp -= 25.0 # fan cooling effect
                
                # Drift towards target temp with some noise
                temp_change = (target_temp - current_temp) * 0.05 + random.uniform(-0.3, 0.3)
                current_temp = max(40.0, min(90.0, current_temp + temp_change))
            
            # Fan Control Hysteresis
            if current_temp > 75.0:
                fan_state = 1
            elif current_temp < 60.0:
                fan_state = 0
                
            # Update Modbus registers
            context[0].setValues(3, load_addr, [int(current_load)])
            context[0].setValues(4, temp_addr, [int(current_temp)])
            context[0].setValues(1, fan_addr, [fan_state])
            context[0].setValues(2, breaker_addr, [breaker_state])
            
        except Exception:
            pass
        await asyncio.sleep(2)

async def run_server():
    config = load_config()
    
    coils = ModbusSequentialDataBlock(0, [0]*100)
    for addr, val in zip(config["DecoyCoilAddrs"], config["DecoyCoilValues"]):
        coils.setValues(addr, [val])
        
    discretes = ModbusSequentialDataBlock(0, [0]*100)
    for addr, val in zip(config["DecoyDiscreteAddrs"], config["DecoyDiscreteValues"]):
        discretes.setValues(addr, [val])
        
    holdings = ModbusSequentialDataBlock(0, [0]*100)
    for addr, val in zip(config["DecoyHoldingAddrs"], config["DecoyHoldingValues"]):
        holdings.setValues(addr, [val])
        
    inputs = ModbusSequentialDataBlock(0, [0]*100)
    for addr, val in zip(config["DecoyInputAddrs"], config["DecoyInputValues"]):
        inputs.setValues(addr, [val])

    # Real initial states
    coils.setValues(config["FanAddr"], [0])
    discretes.setValues(config["BreakerAddr"], [1])
    holdings.setValues(config["LoadAddr"], [100])
    inputs.setValues(config["TempAddr"], [65])
    holdings.setValues(config["TempAddr"], [999]) # Initial temperature holding register override placeholder

    store = ModbusSlaveContext(di=discretes, co=coils, hr=holdings, ir=inputs)
    context = ModbusServerContext(slaves=store, single=True)
    
    asyncio.create_task(update_registers(context, config))
    
    server = LoggingModbusTcpServer(context, address=("0.0.0.0", 5020))
    await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(run_server())
    except KeyboardInterrupt:
        sys.exit(0)
EOF
chmod +x modbus_server

echo "[+] Seeding compromised historical logs..."
cat << 'EOF' > generate_logs.py
import datetime
import json
import os

with open("../.register_map.json", "r") as f:
    config = json.load(f)

fan_addr = config["FanAddr"]
breaker_addr = config["BreakerAddr"]
load_addr = config["LoadAddr"]
temp_addr = config["TempAddr"]

start_time = datetime.datetime(2026, 6, 18, 8, 0, 0)
log_file = "./modbus_server.log"

with open(log_file, "w") as f:
    # 1. Baseline Polling from Approved Client (192.168.1.10)
    for i in range(120):
        t = start_time + datetime.timedelta(minutes=i)
        ts = t.strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 1 - Addr: {fan_addr} - Qty: 1 - Result: Success\n")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 2 - Addr: {breaker_addr} - Qty: 1 - Result: Success\n")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 3 - Addr: {load_addr} - Qty: 1 - Result: Success\n")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 4 - Addr: {temp_addr} - Qty: 1 - Result: Success\n")
        
    # 2. Malicious Scan Injection from Rogue Client (192.168.1.99)
    ts_attack = "2026-06-18 10:05:00"
    f.write(f"{ts_attack} - Client: 192.168.1.99 - FC: 1 - Addr: 0 - Qty: 100 - Result: Success\n")
    f.write(f"{ts_attack} - Client: 192.168.1.99 - FC: 2 - Addr: 0 - Qty: 100 - Result: Success\n")
    f.write(f"{ts_attack} - Client: 192.168.1.99 - FC: 3 - Addr: 0 - Qty: 100 - Result: Success\n")
    f.write(f"{ts_attack} - Client: 192.168.1.99 - FC: 4 - Addr: 0 - Qty: 100 - Result: Success\n")
    
    # 3. Resume Baseline Polling
    for i in range(15):
        t = datetime.datetime(2026, 6, 18, 10, 6, 0) + datetime.timedelta(minutes=i)
        ts = t.strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 1 - Addr: {fan_addr} - Qty: 1 - Result: Success\n")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 2 - Addr: {breaker_addr} - Qty: 1 - Result: Success\n")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 3 - Addr: {load_addr} - Qty: 1 - Result: Success\n")
        f.write(f"{ts} - Client: 192.168.1.10 - FC: 4 - Addr: {temp_addr} - Qty: 1 - Result: Success\n")
EOF
python3 generate_logs.py && rm generate_logs.py
chmod 666 ./modbus_server.log

echo "[+] Starting Modbus TCP Server in background on port 5020..."
nohup ./modbus_server > /dev/null 2> server.err &
sleep 2

echo "[+] Setup Complete. Compromised logs staged at ./modbus_server.log"