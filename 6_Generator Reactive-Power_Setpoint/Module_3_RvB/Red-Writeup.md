# Red Team Lab Walkthrough: Generator Reactive-Power Setpoint Write

## 1. Discovery and Enumeration
1. **Identify the Service:** Run a port scan to locate the OPC UA service.
   `nmap -p 4840 127.0.0.1`
   *Result:* Port 4840 is open.
2. **Browse the Namespace:** Use an OPC UA client (like UA Expert or `asyncua` scripts) to enumerate the tree. Navigate to `Objects -> Generator1`.
3. **Analyze Nodes:** You will see various nodes: `ActivePower`, `Voltage`, `FieldExcitationCurrent`, `RotorSpeed`, and `ReactivePowerSetpoint`.

## 2. Identify the Target
1. Note that nodes like `ActivePower` and `Voltage` are standard read-only parameters.
2. The parameter `ReactivePowerSetpoint` manages process intent. 
3. Verify access levels: By attempting to connect anonymously and reading the `UserAccessLevel` attribute (or attempting a test write), confirm that `ReactivePowerSetpoint` allows unauthenticated writes.

## 3. Execution (T0836 - Modify Parameter)
1. Read the current value of `ReactivePowerSetpoint` to establish the baseline.
   *Result:* Current value is `10.0` Mvar.
2. Write an out-of-policy value that exceeds standard operating bands (e.g., `75.0` Mvar) using the lab execution script. 
   `bash red_attack.sh`
3. The script connects asynchronously, retrieves `ns=2;i=5`, and pushes the new `DataValue`.

## 4. Confirmation
1. Read the node value again to verify the write persisted.
2. The server-side logic will evaluate the parameter deviation (>15.0 Mvar). 
3. **Scoring Condition Met:** The variable is modified outside the approved band, triggering the process deviation alarm in the backend.
