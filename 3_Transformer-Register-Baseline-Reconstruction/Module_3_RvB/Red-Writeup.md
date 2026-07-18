# Red Team Writeup: Discovery & Process Baseline Mapping

**Objective**: Reconstruct the mapping of process variables to Modbus addresses for the substation transformer.

## Scoring Criteria Mapped
1. **Transformer Load (MW)**: FC03 (Holding Registers), Address `68`
2. **Oil Temperature (C)**: FC04 (Input Registers), Address `86`
3. **Cooling Fan State**: FC01 (Coils), Address `90`
4. **Breaker Position**: FC02 (Discrete Inputs), Address `59`

---

## Step-by-Step Manual Solution

### Step 1: Identify the Service (Port Scanning)
Verify if port `5020` is open on the target environment (the default Modbus TCP server port for this challenge):
```bash
nmap -p 5020 127.0.0.1
```
*Result:* Port `5020/tcp` is `open`, confirming a Modbus service is active.

### Step 2: Understand the Physical Process
Examine `process_description.txt` to find variables and engineering ranges:
- **Cooling Fan State**: Toggles ON/OFF (Coil or Discrete Input).
- **Breaker Position**: Indicates OPEN or CLOSED (Coil or Discrete Input).
- **Transformer Load (MW)**: Fluctuates continuously between `50 MW` and `150 MW` (Holding or Input Register).
- **Oil Temperature (C)**: Drifts slowly between `40 C` and `90 C` (Holding or Input Register).

*Note: Static decoy registers are seeded to deceive scanners.*

### Step 3: Run Interactive Python Scan (Multi-Run Delta Analysis)
Write a Python script to scan registers 0-99 across all four function codes, then run it multiple times to observe fluctuations.

Create `recon.py`:
```python
import time
from pymodbus.client import ModbusTcpClient

client = ModbusTcpClient('127.0.0.1', port=5020)
client.connect()

print("--- FC01 (Coils) ---")
print("Run 1:", client.read_coils(0, 100).bits[:30])
time.sleep(3)
print("Run 2:", client.read_coils(0, 100).bits[:30])

print("--- FC02 (Discrete Inputs) ---")
print("Run 1:", client.read_discrete_inputs(0, 100).bits[:30])
time.sleep(3)
print("Run 2:", client.read_discrete_inputs(0, 100).bits[:30])

print("--- FC03 (Holding Registers) ---")
print("Run 1:", client.read_holding_registers(0, 100).registers[:30])
time.sleep(3)
print("Run 2:", client.read_holding_registers(0, 100).registers[:30])

print("--- FC04 (Input Registers) ---")
print("Run 1:", client.read_input_registers(0, 100).registers[:30])
time.sleep(3)
print("Run 2:", client.read_input_registers(0, 100).registers[:30])

client.close()
```

Run the script:
```bash
python3 recon.py
```

### Step 4: Analyze Fluctuations & Filter Decoys
1. **Coils (FC01)**:
   - Address `32` is static at `True` (decoy).
   - Address `90` toggles dynamically between `True` and `False`. $\rightarrow$ **Cooling Fan State = Address 90**
2. **Discrete Inputs (FC02)**:
   - Address `76` is static at `True` (decoy).
   - Address `59` toggles dynamically between `True` and `False`. $\rightarrow$ **Breaker Position = Address 59**
3. **Holding Registers (FC03)**:
   - Address `34` is static at `95` (decoy).
   - Address `68` fluctuates dynamically between `50` and `150`. $\rightarrow$ **Transformer Load = Address 68**
4. **Input Registers (FC04)**:
   - Address `51` is static at `400` (decoy).
   - Address `86` drifts dynamically between `40` and `90`. $\rightarrow$ **Oil Temperature = Address 86**

---

## Flag Submission format
Submit the four discovered integer addresses in the format: `[LoadAddr]-[TempAddr]-[FanAddr]-[BreakerAddr]`

**Flag:** `68-86-90-59`
