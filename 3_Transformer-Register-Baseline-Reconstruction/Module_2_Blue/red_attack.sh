#!/usr/bin/env bash
# red_attack.sh - Self-contained Red Team Modbus Reconnaissance Tool
# Run directly with ./red_attack.sh or bash red_attack.sh

python3 - << 'EOF'
import sys
import argparse
from pymodbus.client import ModbusTcpClient

# Parse optional target parameters
parser = argparse.ArgumentParser(description="Modbus Recon Tool")
parser.add_argument("ip", nargs="?", default="127.0.0.1", help="Target IP address (default: 127.0.0.1)")
parser.add_argument("port", nargs="?"a, type=int, default=5020, help="Target Port (default: 5020)")
args = parser.parse_args()

TARGET_IP = args.ip
PORT = args.port

def run_scan():
    client = ModbusTcpClient(TARGET_IP, port=PORT)
    if not client.connect():
        print(f"[-] ERROR: Failed to connect to Modbus server at {TARGET_IP}:{PORT}")
        sys.exit(1)
        
    print(f"[+] Connected to Modbus TCP server at {TARGET_IP}:{PORT}")
    print("[+] Commencing systematic scans (registers 0-99)...")
    
    # 1. FC01 - Coils
    print("\n--- FC01: Coils ---")
    res = client.read_coils(0, count=100, slave=1)
    if not res.isError():
        for i, val in enumerate(res.bits[:100]):
            if val:
                print(f"[FC01 - Coil] Address {i}: {val}")
    else:
        print(f"[-] FC01 Read Error: {res}")
        
    # 2. FC02 - Discrete Inputs
    print("\n--- FC02: Discrete Inputs ---")
    res = client.read_discrete_inputs(0, count=100, slave=1)
    if not res.isError():
        for i, val in enumerate(res.bits[:100]):
            if val:
                print(f"[FC02 - Discrete Input] Address {i}: {val}")
    else:
        print(f"[-] FC02 Read Error: {res}")
        
    # 3. FC03 - Holding Registers
    print("\n--- FC03: Holding Registers ---")
    res = client.read_holding_registers(0, count=100, slave=1)
    if not res.isError():
        for i, val in enumerate(res.registers):
            if val != 0:
                print(f"[FC03 - Holding Register] Address {i}: {val}")
    else:
        print(f"[-] FC03 Read Error: {res}")
        
    # 4. FC04 - Input Registers
    print("\n--- FC04: Input Registers ---")
    res = client.read_input_registers(0, count=100, slave=1)
    if not res.isError():
        for i, val in enumerate(res.registers):
            if val != 0:
                print(f"[FC04 - Input Register] Address {i}: {val}")
    else:
        print(f"[-] FC04 Read Error: {res}")
        
    client.close()
    print("\n[+] Scan Complete.")

if __name__ == "__main__":
    run_scan()
EOF