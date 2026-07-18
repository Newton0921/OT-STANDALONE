#!/bin/bash
# DNP3 Sequence Anomaly Lab - Red Setup Script
# OS: Ubuntu 22.04 LTS

echo "[*] Updating system and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y tcpdump nmap python3

# Create working directories
mkdir -p /opt/dnp3_lab/logs
mkdir -p /opt/dnp3_lab/pcap
chmod -R 777 /opt/dnp3_lab

# Create the Approved Master Whitelist
echo "[*] Creating master address whitelist..."
cat << 'EOF' > /opt/dnp3_lab/whitelist.txt
APPROVED_MASTERS:
10.0.0.50 - DNP3_Master_Addr: 1
EOF

# Kill any existing simulation instances
pkill -f outstation_sim.py || true
pkill -f master_sim.py || true

# Write Outstation Simulator (Python DNP3 stack simulation)
# Real OpenDNP3 C++ outstations use point-specific parameters or command handler configurations
# to enforce stateful SBO tracking. This simulation exposes SBO vulnerabilities by accepting
# Direct Operate (FC3) from any link-layer address without verifying a preceding Select (FC1).
echo "[*] Writing Outstation Simulator..."
cat << 'EOF' > /opt/dnp3_lab/outstation_sim.py
import socket
import struct
import time
import os
import sys

def crc16(data):
    crc = 0x0000
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if (crc & 1):
                crc = (crc >> 1) ^ 0xA6BC
            else:
                crc >>= 1
    return ~crc & 0xFFFF

def make_dnp3_frame(control, dest_addr, src_addr, payload=b""):
    start = b'\x05\x64'
    length = 5 + len(payload)
    hdr_data = start + bytes([length, control]) + struct.pack('<H', dest_addr) + struct.pack('<H', src_addr)
    hdr_crc = struct.pack('<H', crc16(hdr_data))
    
    payload_with_crcs = b""
    for i in range(0, len(payload), 16):
        block = payload[i:i+16]
        payload_with_crcs += block + struct.pack('<H', crc16(block))
        
    return hdr_data + hdr_crc + payload_with_crcs

def load_whitelist():
    return [1]

def log_event(message):
    log_dir = "/opt/dnp3_lab/logs"
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "dnp3_protocol.log")
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(log_path, "a") as f:
        f.write(f"{timestamp} {message}\n")
        f.flush()
    print(f"{timestamp} {message}")

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', 20000))
    except Exception as e:
        print(f"Error binding to port 20000: {e}")
        sys.exit(1)
        
    server.listen(5)
    log_event("[BASELINE] Outstation started. Listening on 20000.")
    
    breaker_state = "CLOSED"
    last_select = {}
    
    try:
        while True:
            conn, addr = server.accept()
            try:
                while True:
                    data = conn.recv(1024)
                    if not data:
                        break
                    
                    if len(data) < 10:
                        continue
                    if data[0] != 0x05 or data[1] != 0x64:
                        continue
                    
                    length = data[2]
                    control = data[3]
                    dest_addr = struct.unpack('<H', data[4:6])[0]
                    src_addr = struct.unpack('<H', data[6:8])[0]
                    
                    payload_len = length - 5
                    if payload_len <= 0:
                        resp = make_dnp3_frame(0x0b, src_addr, dest_addr)
                        conn.send(resp)
                        continue
                    
                    payload_raw = data[10:]
                    payload = b""
                    idx = 0
                    while idx < len(payload_raw):
                        block = payload_raw[idx:idx+16]
                        payload += block
                        idx += 18
                    
                    if len(payload) < 3:
                        continue
                    
                    transport_hdr = payload[0]
                    app_ctrl = payload[1]
                    func_code = payload[2]
                    seq_num = app_ctrl & 0x0f
                    resp_payload = b""
                    
                    if len(payload) >= 8 and payload[3] == 0x0c and payload[4] == 0x01:
                        qualifier = payload[5]
                        count = payload[6]
                        index = 0
                        if qualifier == 0x28 or qualifier == 0x17:
                            index = struct.unpack('<H', payload[7:9])[0]
                            crob_block = payload[3:20]
                        else:
                            index = payload[7]
                            crob_block = payload[3:20]
                        
                        if func_code == 0x01: # Select
                            last_select[src_addr] = index
                            log_event(f"[BASELINE] Master Addr: {src_addr} | Outstation: {dest_addr} | FC: 1 (Select) | Index: {index}")
                            resp_payload = bytes([0xc0 | seq_num, 0x81, 0x00, 0x00]) + crob_block
                            
                        elif func_code == 0x04: # Operate
                            if last_select.get(src_addr) == index:
                                last_select[src_addr] = None
                                log_event(f"[BASELINE] Master Addr: {src_addr} | Outstation: {dest_addr} | FC: 4 (Operate) | Index: {index} | Status: SUCCESS")
                            else:
                                log_event(f"[WARNING] Master Addr: {src_addr} | Outstation: {dest_addr} | FC: 4 (Operate) | Index: {index} | Status: SUCCESS (No SBO Select)")
                            resp_payload = bytes([0xc0 | seq_num, 0x81, 0x00, 0x00]) + crob_block
                                
                        elif func_code == 0x03: # Direct Operate
                            whitelist = load_whitelist()
                            if src_addr not in whitelist:
                                log_event(f"[ANOMALY]  Master Addr: {src_addr} | Outstation: {dest_addr} | FC: 3 (Direct Operate) | Index: {index} | Status: SUCCESS")
                                breaker_state = "OPEN"
                                log_event(f"[PROCESS_STATE_CHANGE] Feeder Breaker (Index {index}) transitioned to {breaker_state} state.")
                            else:
                                log_event(f"[BASELINE] Master Addr: {src_addr} | Outstation: {dest_addr} | FC: 3 (Direct Operate) | Index: {index} | Status: SUCCESS")
                            resp_payload = bytes([0xc0 | seq_num, 0x81, 0x00, 0x00]) + crob_block
                    else:
                        resp_payload = bytes([0xc0 | seq_num, 0x81, 0x00, 0x00])
                    
                    if resp_payload:
                        resp = make_dnp3_frame(0x44, src_addr, dest_addr, resp_payload)
                        conn.send(resp)
            except Exception as e:
                pass
            finally:
                conn.close()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()

if __name__ == '__main__':
    main()
EOF

# Write Master Simulator (Approved SCADA Master sending normal SBO baseline)
echo "[*] Writing Master Simulator..."
cat << 'EOF' > /opt/dnp3_lab/master_sim.py
import socket
import time
import struct

def crc16(data):
    crc = 0x0000
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if (crc & 1):
                crc = (crc >> 1) ^ 0xA6BC
            else:
                crc >>= 1
    return ~crc & 0xFFFF

def make_dnp3_frame(control, dest_addr, src_addr, payload=b""):
    start = b'\x05\x64'
    length = 5 + len(payload)
    hdr_data = start + bytes([length, control]) + struct.pack('<H', dest_addr) + struct.pack('<H', src_addr)
    hdr_crc = struct.pack('<H', crc16(hdr_data))
    
    payload_with_crcs = b""
    for i in range(0, len(payload), 16):
        block = payload[i:i+16]
        payload_with_crcs += block + struct.pack('<H', crc16(block))
        
    return hdr_data + hdr_crc + payload_with_crcs

def send_sbo():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect(('127.0.0.1', 20000))
        
        # 1. Select
        select_pld = b'\xc0\xc0\x01\x0c\x01\x28\x01\x07\x00\x01\x01\x01\x00\x00\x00\x00'
        select_frame = make_dnp3_frame(0xc4, 10, 1, select_pld)
        s.send(select_frame)
        s.recv(1024)
        
        time.sleep(1)
        
        # 2. Operate
        operate_pld = b'\xc0\xc1\x04\x0c\x01\x28\x01\x07\x00\x01\x01\x01\x00\x00\x00\x00'
        operate_frame = make_dnp3_frame(0xc4, 10, 1, operate_pld)
        s.send(operate_frame)
        s.recv(1024)
        s.close()
    except Exception as e:
        pass

def main():
    while True:
        send_sbo()
        time.sleep(15)

if __name__ == '__main__':
    main()
EOF

# Make simulators executable and set directory permissions
chmod +x /opt/dnp3_lab/outstation_sim.py /opt/dnp3_lab/master_sim.py
chmod -R 777 /opt/dnp3_lab

# Start Outstation
nohup python3 /opt/dnp3_lab/outstation_sim.py > /opt/dnp3_lab/logs/outstation.out 2>&1 &
sleep 1

# Start Master Simulator to seed normal SBO baseline
nohup python3 /opt/dnp3_lab/master_sim.py > /opt/dnp3_lab/logs/master.out 2>&1 &

# Start tcpdump PCAP capture on DNP3 TCP port 20000
nohup tcpdump -i any -n -w /opt/dnp3_lab/pcap/dnp3_traffic.pcap tcp port 20000 > /dev/null 2>&1 &

echo "[*] Red Lab Setup Complete. Outstation running on TCP 20000."