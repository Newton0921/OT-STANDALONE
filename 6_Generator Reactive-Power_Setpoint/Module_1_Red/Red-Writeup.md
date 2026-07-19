
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
<img width="792" height="47" alt="image" src="https://github.com/user-attachments/assets/2656a72a-db9c-4a88-ad4e-78d68c77b8f6" />






METHOD 2

Step 1: Network Discovery (Port Scanning)
Industrial Control Systems often use the OPC UA protocol for unified communications. OPC UA services traditionally run on TCP port 4840. Run a quick Nmap scan against the target to verify the port is exposed:

bash
nmap -p 4840 127.0.0.1
Result: Port 4840 is confirmed to be open.

Step 2: Connect and Enumerate the Namespace
Unlike older protocols that use raw memory addresses (like Modbus), OPC UA has a rich, human-readable directory structure known as a Namespace.

Open an OPC UA GUI Client (like UaExpert) and connect to the endpoint:

Endpoint URL: opc.tcp://127.0.0.1:4840
Authentication: Anonymous (No Credentials)
Once connected, browse the Address Space pane on the left. Expand the Root -> Objects -> Generator1 folder. You will discover the following tree structure:

t```text
Root
└── Objects
    └── Generator1 (ns=2;i=1)
        ├── ActivePower               (ns=2;i=2)  RO
        ├── Voltage                   (ns=2;i=3)  RO
        ├── ReactivePower             (ns=2;i=4)  RO
        ├── ReactivePowerSetpoint     (ns=2;i=5)  RW  <-- Control Variable
        ├── FieldExcitationCurrent    (ns=2;i=6)  RO
        └── RotorSpeed                (ns=2;i=7)  RO
```
Step 3: Identify the Vulnerability
If you click through the nodes in the Generator1 object, you will notice that parameters like Voltage and RotorSpeed have an AccessLevel of CurrentRead.

However, if you inspect the ReactivePowerSetpoint node (ns=2;i=5), you will discover a critical misconfiguration: the AccessLevel is set to CurrentRead, CurrentWrite for Anonymous users!

This means an attacker can push unauthorized values directly to the generator's control logic.

Step 4: Execution (The Attack)
The normal baseline for the Reactive Power Setpoint is 10.0 Mvar. To destabilize the generator and successfully solve the challenge, you must write a massive, out-of-bounds value (e.g., 75.0 Mvar) to the setpoint.

You can execute this attack using either the UaExpert GUI or the command line.

Method A: Using the UaExpert GUI

Drag the ReactivePowerSetpoint node into the middle "Data Access View" pane.
Double-click the live Value cell (which currently reads 10.0).
Type in the malicious payload: 75.0 and press Enter.
Method B: Using the Command Line (opcua-client) If you prefer the terminal, you can push the malicious float directly to Node ns=2;i=5 using a standard OPC UA command-line tool:

bash
opcua-client write "opc.tcp://127.0.0.1:4840" "ns=2;i=5" --type Double 75.0
Step 5: Verification
As soon as the malicious setpoint (75.0) is pushed to the server, the backend ICS logic detects that the value has violently breached the approved operating band (5.0 to 15.0 Mvar).

A DeviationAlarm is immediately triggered in the process logs.

Challenge Completed!


**Challenge Completed!**
