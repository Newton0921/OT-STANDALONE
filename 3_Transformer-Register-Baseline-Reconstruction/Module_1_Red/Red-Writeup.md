# Red Team Writeup: Discovery & Process Baseline Mapping

**Objective**: Reconstruct the mapping of process variables to Modbus addresses for the substation transformer.

## Scoring Criteria Mapped
1. **Transformer Load (MW)**: FC03 (Holding Registers), Address `68`
2. **Oil Temperature (C)**: FC04 (Input Registers), Address `86`
3. **Cooling Fan State**: FC01 (Coils), Address `90`
4. **Breaker Position**: FC02 (Discrete Inputs), Address `59`

---

Step 1: Initialize the Red Environment

First, navigate to the Red Module directory and execute the setup script:

bash

cd /home/newton/Hacktify/3_Transformer-Register-Baseline-Reconstruction/Module_1_Red

sudo ./setup.sh

(This starts the simulated Modbus server in the background on port 5020)


Step 2: Perform a Port Scan

Verify that the Modbus TCP service is up and listening:



bash

nmap -p 5020 127.0.0.1

Expected Result: Port 5020 should show as open<img width="786" height="553" alt="image" src="https://github.com/user-attachments/assets/c20a784e-c915-490d-897e-03440fea5cd6" />



Step 3: Run the Delta Analysis Scan

Run the attack/scan script multiple times to observe register changes:



bash

./red_attack.sh 127.0.0.1 5020 --repeat 3 --delay 2

Step 4: Identify Real Registers vs. Decoys

Analyze the outputs from the scan:



Coils (FC01): Look for the register address that changes state between True/False (or 1/0).

Result: Address 90 changes dynamically. Address 32 is static (decoy). (Cooling Fan = 90)

Discrete Inputs (FC02): Look for the register address toggling states.

Result: Address 59 changes dynamically. (Breaker Position = 59)

Holding Registers (FC03): Look for a register carrying load values (fluctuating between 50 and 150).

Result: Address 68 changes value dynamically. Address 34 stays stuck at 95 (decoy). (Transformer Load = 68)

Input Registers (FC04): Look for a register representing temperature (drifting slowly between 40 and 90).

Result: Address 86 drifts dynamically. Address 51 stays stuck at 400 (decoy). (Oil Temperature = 86)

Step 5: Formulate the Flag

Put the discovered addresses in the submission format [LoadAddr]-[TempAddr]-[FanAddr]-[BreakerAddr]:



Flag: 68-86-90-59
























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

## Updated Simulation Details (Stateful Behaviour)
The Modbus server now emulates a realistic physical process:
- **Load dynamics**: The holding register at address 68 (MW) fluctuates between 50‑150 MW while the breaker is closed. If load exceeds 140 MW there is a ~15 % chance the breaker trips, forcing the breaker discrete (address 59) open and setting load to 0 MW for a short outage before the server auto‑closes the breaker and restores a nominal load of 80 MW.
- **Temperature model**: The input register at address 86 (°C) follows a first‑order lag based on the current load and includes small Gaussian noise (±0.5 °C). When the fan coil (address 90) is ON, temperature is reduced by ~25 °C.
- **Fan control loop**: The fan coil is automatically switched ON when temperature > 75 °C and OFF when temperature < 60 °C, providing hysteresis. Manual writes to the fan coil override this automatic state.
- **Breaker feedback**: Writing 0 to the breaker discrete (address 59) opens the breaker, forcing load to 0 MW for a 5‑second outage; the server then automatically closes the breaker and restores a baseline load.
- **Sensor noise**: Input registers (including temperature) are presented with slight random noise to mimic real sensor readings.
These dynamics cause register values to change on each scan, requiring multi‑run delta analysis to differentiate true process variables from static decoys.
