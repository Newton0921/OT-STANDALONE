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
Step 1: Find the Attacker (Rogue Client ID & IP)
Search the broker's log to see the connection history and identify the unauthorized user.

Run this command:

Bash
grep -i "New client connected" /tmp/mqtt_lab/log/mosquitto.log
Answers to record:

Rogue Client ID: rogue_solar_client

Source IP: 10.0.5.112

Step 2: Find the Forged Data (Payload & Topic)
Search the log to find exactly what data the rogue client injected to manipulate the dashboard.

Run this command:

Bash
grep -A 1 -i "rogue_solar_client PUBLISH" /tmp/mqtt_lab/log/mosquitto.log
Answers to record:

Target Topic: grid/solar/site7/kw

First Forged Payload: 150.00

Step 3: Prove it was an Attack (The Anomaly)
Check the physical ground-truth logs to prove the dashboard data was physically impossible.

Run this command:

Bash
cat /tmp/mqtt_lab/log/ground_truth.log
Answer to record:

Anomaly Evidence: Impossible rate-of-change. The log proves the physical solar array was only generating ~49.88 kW at the exact time the attacker injected the 150.00 kW value.

Step 4: Find the Root Cause (Misconfiguration)
Check the broker's security configuration to see why the attacker was allowed to publish.

Run these commands:

Bash
cat /tmp/mqtt_lab/config/mosquitto.conf
cat /tmp/mqtt_lab/config/acl


Answer to record:

Root Cause: The broker was set to allow_anonymous true (no authentication), and the ACL file used pattern readwrite grid/solar/site7/#, granting everyone full read and write access to the telemetry topic.