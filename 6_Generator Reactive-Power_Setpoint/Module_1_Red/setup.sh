#!/bin/bash
# Module 1: Red Participant Setup Script
echo "[*] Setting up Generator Reactive-Power Setpoint Lab (Red)..."

# Install dependencies
sudo apt-get update || true
sudo apt-get install -y python3 python3-pip nmap netcat-openbsd || true
pip3 install asyncua opcua-client --break-system-packages || pip3 install --user asyncua opcua-client || pip3 install asyncua opcua-client || true

# Kill any existing instance to ensure port binding is clean
pkill -f asyncua_server.py || true

# Create the ICS Server script
cat << 'EOF' > asyncua_server.py
import asyncio
from asyncua import Server, ua
from datetime import datetime

async def main():
    server = Server()
    await server.init()
    server.set_endpoint("opc.tcp://0.0.0.0:4840/freeopcua/server/")
    server.set_server_name("Generator Control Server")
    server.set_security_policy([ua.SecurityPolicyType.NoSecurity])

    # Namespace setup
    uri = "http://hacktify.training/generator"
    idx = await server.register_namespace(uri)

    # Node Setup (Explicit Node IDs to align with forensic logs and exploit script)
    gen_obj = await server.nodes.objects.add_object(ua.NodeId(1, idx), "Generator1")
    
    # Decoy / Read-only Nodes
    await gen_obj.add_variable(ua.NodeId(2, idx), "ActivePower", 50.0)
    await gen_obj.add_variable(ua.NodeId(3, idx), "Voltage", 13.8)
    await gen_obj.add_variable(ua.NodeId(4, idx), "ReactivePower", 10.0)
    
    # Target Setpoint Node (ns=2;i=5)
    setpoint = await gen_obj.add_variable(ua.NodeId(5, idx), "ReactivePowerSetpoint", 10.0)
    # VULNERABILITY: Enabling anonymous write access on setpoint
    await setpoint.set_writable()

    # Remaining decoy nodes
    await gen_obj.add_variable(ua.NodeId(6, idx), "FieldExcitationCurrent", 310.5)
    await gen_obj.add_variable(ua.NodeId(7, idx), "RotorSpeed", 3600.0)

    # Initialize logs
    ts = datetime.now().isoformat()
    with open("baseline_log.txt", "w") as f:
        f.write(f"[{ts}] BASELINE | ReactivePowerSetpoint = 10.0 Mvar\n")
    with open("session_log.txt", "w") as f:
        f.write(f"[{ts}] SESSION OPEN | SessionID: ns=1;i=101 | IP: 192.168.10.50 | Token: Username\n")

    print("[+] OPC UA Server Started on port 4840. Awaiting connections...")
    
    # Background monitor for process logging
    async with server:
        last_val = 10.0
        while True:
            await asyncio.sleep(1)
            current_val = await setpoint.read_value()
            if current_val != last_val:
                evt_ts = datetime.now().isoformat()
                
                # Write to respective logs
                with open("session_log.txt", "a") as f:
                    f.write(f"[{evt_ts}] SESSION OPEN | SessionID: ns=1;i=105 | IP: 10.10.10.100 | Token: Anonymous\n")
                with open("write_event_log.txt", "a") as f:
                    f.write(f"[{evt_ts}] WRITE EVENT | SessionID: ns=1;i=105 | NodeID: ns=2;i=5 | OldValue: {last_val} | NewValue: {current_val}\n")
                with open("value_change_log.txt", "a") as f:
                    f.write(f"[{evt_ts}] VALUE CHANGE | NodeID: ns=2;i=5 | {last_val} -> {current_val}\n")
                
                # Alarm Logic (Approved Band: 5.0 to 15.0)
                if current_val > 15.0 or current_val < 5.0:
                    with open("process_alarm_log.txt", "a") as f:
                        f.write(f"[{evt_ts}] ALARM | Type: DeviationAlarm | NodeID: ns=2;i=5 | ThresholdBreached: OUT OF BAND | AlarmValue: {current_val}\n")
                
                last_val = current_val

if __name__ == '__main__':
    asyncio.run(main())
EOF

# Start Server in Background
python3 asyncua_server.py &
echo "[*] Environment deployed. Logs are active."