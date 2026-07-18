# Blue Team Lab Walkthrough: Forensic Analysis & Detection

## 1. Operational Overview
As an OT security analyst, you are investigating a critical `DeviationAlarm` on a generator's voltage-control system. A reactive-power parameter unexpectedly spiked, forcing the system outside its approved operational band.

Your objective is to inspect the synthesized application logs and reconstruct the attack timeline.

---

## 2. Step-by-Step Forensic Log Analysis

### Step 1: Establish the Process Baseline
Review the baseline configuration log to determine the approved setpoint configuration:
```bash
cat baseline_log.txt
```
*Result:*
```text
[2026-06-18T10:00:00.000000] BASELINE | ReactivePowerSetpoint = 10.0 Mvar
```
The normal operational setpoint is **10.0 Mvar**.

### Step 2: Investigate Active Sessions
Examine the OPC UA session logs to trace client connections:
```bash
cat session_log.txt
```
*Result:*
```text
[2026-06-18T10:00:00.000000] SESSION OPEN | SessionID: ns=1;i=101 | IP: 192.168.10.50 | Token: Username
[2026-06-18T10:15:00.000000] SESSION OPEN | SessionID: ns=1;i=102 | IP: 192.168.10.50 | Token: Username
[2026-06-18T10:22:45.123456] SESSION OPEN | SessionID: ns=1;i=105 | IP: 10.10.10.100 | Token: Anonymous
```
*Key Discovery:*
An unauthorized connection was established from IP **10.10.10.100** at **10:22:45.123456** using an **Anonymous token** (SessionID: `ns=1;i=105`).

### Step 3: Analyze Write Events
Correlate the unauthorized session with modifications inside the namespace:
```bash
cat write_event_log.txt
```
*Result:*
```text
[2026-06-18T10:22:45.123456] WRITE EVENT | SessionID: ns=1;i=105 | NodeID: ns=2;i=5 | OldValue: 10.0 | NewValue: 75.0
```
*Key Discovery:*
Session `ns=1;i=105` successfully issued a write command to NodeID **`ns=2;i=5`**, changing its value from **10.0** to **75.0**.

### Step 4: Trace the Parameter Value Change
Verify if the setpoint change persisted on the controller:
```bash
cat value_change_log.txt
```
*Result:*
```text
[2026-06-18T10:22:45.123456] VALUE CHANGE | NodeID: ns=2;i=5 | 10.0 -> 75.0
```
The value indeed transitioned to **75.0** on the physical simulator.

### Step 5: Review Alarm Logs
Review the process alarm log to see the operational impact of the modification:
```bash
cat process_alarm_log.txt
```
*Result:*
```text
[2026-06-18T10:22:45.123456] ALARM | Type: DeviationAlarm | NodeID: ns=2;i=5 | ThresholdBreached: OUT OF BAND | AlarmValue: 75.0
```
The write triggered a `DeviationAlarm` because **75.0 Mvar** breaches the approved operational range of **5.0 to 15.0 Mvar**.

---

## 3. Incident Reconstruction (TIMELINE)

| Timestamp | Source IP | Session ID | Event Type | Details |
| :--- | :--- | :--- | :--- | :--- |
| **10:00:00** | 192.168.10.50 | `ns=1;i=101` | SESSION OPEN | Authorized engineering session (Username token) |
| **10:15:00** | 192.168.10.50 | `ns=1;i=102` | SESSION OPEN | Authorized engineering session (Username token) |
| **10:22:45** | 10.10.10.100 | `ns=1;i=105` | SESSION OPEN | **Unauthorized connection** (Anonymous token) |
| **10:22:45** | 10.10.10.100 | `ns=1;i=105` | WRITE EVENT | **Parameter Manipulation:** Changed Node `ns=2;i=5` value to `75.0` |
| **10:22:45** | Local System | - | ALARM | **DeviationAlarm** triggered; process halted |

---

## 4. Remediation and Hardening

1. **Disable Anonymous Write Access (Least Privilege):** 
   Update OPC UA server policy to restrict write permissions on parameter setpoints to authenticated engineering accounts only:
   ```python
   # Do not use set_writable() without strict role-based access controls (RBAC)
   ```
2. **Enforce Authentication (MFA / Certificate-based):**
   Reject anonymous connections in production. Configure the OPC UA server to require username/password or cryptographic client certificates.
3. **Input Range Validation:**
   Enforce input validation at the OPC UA server layer to automatically reject parameter writes that fall outside the safe operational limits (5.0 to 15.0 Mvar).
4. **Network Segmentation:**
   Deploy firewall rules to block port 4840 access from non-engineering zones.
