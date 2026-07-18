# Blue Team Walkthrough: Rogue Solar Telemetry Publisher

## 1. Scenario & Investigative Scope
As a Blue Team incident responder, you are investigating an anomalous spike on the energy management dashboard. The physical solar array is operating under normal weather conditions, generating ~40-50 kW, but the telemetry dashboard suddenly jumped to `150.00 kW`. 

Your objectives are to:
1. Locate and acquire the relevant forensic logs.
2. Identify the rogue publisher's Client ID.
3. Determine the rogue publisher's Source IP address.
4. Identify the first forged payload value and targeted topic.
5. Capture anomaly evidence demonstrating an impossible rate-of-change.
6. Conduct root cause analysis on the broker configuration.
7. Implement defensive remediation to secure the telemetry pipeline.

---

## 2. MITRE ATT&CK for ICS Mapping
- **Tactic:** Impair Process Control (TA0106)
- **Technique:** Unauthorized Message: Reporting Message (T1692.002)

---

## 3. Step-by-Step Forensics Walkthrough

### Step 1: Log Acquisition
Navigate to the broker's log directory where the environment records are kept:
- **Broker Logs:** `/tmp/mqtt_lab/log/mosquitto.log` (Tracks connections, subscriptions, and published messages).
- **Physical Ground Truth Logs:** `/tmp/mqtt_lab/log/ground_truth.log` (Tracks physical sensor readings directly from the source).

### Step 2: Connection Analysis (Locating the Rogue Entity)
To find when and from where the rogue client connected, search the broker log for connection events:
```bash
grep -i "New client connected" /tmp/mqtt_lab/log/mosquitto.log
```

**Expected Output:**
```text
1781863568: New client connected from 192.168.10.55 as solar_publisher_site7 (p2, c1, k60).
1781863723: New client connected from 10.0.5.112 as rogue_solar_client (p2, c1, k60).
```
*Analysis:* 
- The legitimate solar publisher baseline is Client ID `solar_publisher_site7` connecting from IP `192.168.10.55`.
- A highly suspicious client named `rogue_solar_client` connected from IP `10.0.5.112` at Unix timestamp `1781863723`.
- **Rogue Client ID:** `rogue_solar_client`
- **Rogue IP Address:** `10.0.5.112`

### Step 3: Payload & Topic Forensics
Identify the target topic and the payload that was injected by searching the log for messages published by `rogue_solar_client`:
```bash
grep -A 1 -i "rogue_solar_client PUBLISH" /tmp/mqtt_lab/log/mosquitto.log
```

**Expected Output:**
```text
1781863723: Client rogue_solar_client PUBLISH (d0, q0, r1, m0, 'grid/solar/site7/kw', ... (6 bytes))
1781863723: 	Payload: 150.00
```
*Analysis:*
- **Target Topic:** `grid/solar/site7/kw`
- **First Forged Payload:** `150.00` (representing 150.00 kW)
- **Timestamp:** `1781863723` (equivalent to `2026-06-19 15:38:43 UTC`)

### Step 4: Quantifying the Anomaly (Impossible Rate-of-Change)
Correlate the timestamp of the rogue publication (`2026-06-19 15:38:43`) with the physical ground truth sensor readings in `ground_truth.log` to calculate the discrepancy.
```bash
cat /tmp/mqtt_lab/log/ground_truth.log
```

**Relevant Log Snippet:**
```text
2026-06-19T15:38:18 - 49.82 kW
2026-06-19T15:38:28 - 49.93 kW
2026-06-19T15:38:43 - 49.88 kW
```
*Analysis:*
- The actual physical output at `15:38:43` was `49.88 kW`.
- The injected telemetry payload value was `150.00 kW`.
- **Discrepancy:** `+100.12 kW` (an instantaneous jump from ~49 kW to 150 kW).
- **Physical Anomaly:** Solar irradiance does not double or triple in < 1 second. This instantaneous rate-of-change represents a physical impossibility, proving data integrity was compromised.

### Step 5: Root Cause Analysis
Examine the broker's configuration files `/tmp/mqtt_lab/config/mosquitto.conf` and ACL settings `/tmp/mqtt_lab/config/acl`:
```bash
cat /tmp/mqtt_lab/config/mosquitto.conf
cat /tmp/mqtt_lab/config/acl
``
grep -in "payload" /tmp/mqtt_lab/log/mosquitto.log(MAIN)

**Configuration Weaknesses:**
1. **`allow_anonymous true`:** Allows any client on the network to connect without credentials.
2. **`pattern readwrite grid/solar/site7/#`:** Grants every client full read/write access to any topic under `grid/solar/site7/` without verifying the client ID.

---

