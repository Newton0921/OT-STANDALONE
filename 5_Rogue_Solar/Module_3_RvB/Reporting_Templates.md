# Incident Reporting Templates

This document contains standard reporting templates for both Red and Blue team operators participating in the Rogue Solar Telemetry Publisher challenge.

---

## 1. Incident Notification Report (INREP)

*This report is submitted by the Blue Team immediately upon identifying initial anomalous behavior.*

```markdown
# Incident Notification Report (INREP)

**Cyber Exercise — Operation Rogue Solar**
**Version 1.0**

---

**Date:** [YYYY-MM-DD]
**Time:** [Time of Incident]
**Report ID:** IN-SOLAR-M03

---

## 1. Current Situation

**Description:** The telemetry dashboard was compromised via a misconfiguration in the Mosquitto MQTT broker on port 1883. An unauthorized client (`rogue_solar_client`) exploited the permissive write access of the broker to publish a forged solar generation payload of `150.00 kW` on the topic `grid/solar/site7/kw`. This forged reading represents a massive deviation from the physical ground truth (~49 kW). Immediate investigation and containment are required to restore telemetry integrity.

**Threat Level:** High

**Areas of Concern:**
- Exploitation of `allow_anonymous` and broad ACL write permissions (`pattern readwrite grid/solar/site7/#`) allowing unauthorised access to privileged publication functionality.
- Potential data spoofing enabling attacker manipulation of grid operations and load balancing decisions.
- Risk of cascading compromise across the SCADA/OT network segment.

---

## 2. Threat Intelligence

**Sources:**
- Mosquitto Broker Logs: `/tmp/mqtt_lab/log/mosquitto.log`
- Command to query logs: `grep -i "New client connected" /tmp/mqtt_lab/log/mosquitto.log`

**Indicators of Compromise (IOCs):**
- Connection from unauthorized source IP `10.0.5.112` using Client ID `rogue_solar_client`.
- Abnormal payload of `150.00` on the `grid/solar/site7/kw` topic with the retain flag set.

**Log Entry Identified:**
```text
1781863723: New client connected from 10.0.5.112 as rogue_solar_client (p2, c1, k60).
1781863723: Client rogue_solar_client PUBLISH (d0, q0, r1, m0, 'grid/solar/site7/kw', ... (6 bytes))
1781863723: 	Payload: 150.00
```

---

## 3. Vulnerability Identification

**Vulnerability:** Anonymous MQTT Access & Broad Access Control Lists (ACLs)

**Affected Parameter:** `allow_anonymous true` and permissive ACL (`pattern readwrite grid/solar/site7/#`) in `/tmp/mqtt_lab/config/mosquitto.conf` and `/tmp/mqtt_lab/config/acl`.

**Description:** The Mosquitto broker processes the publication messages without enforcing authentication or validating the Client ID against specific topics. This allows any attacker on the network to connect anonymously and publish forged telemetry.

**Patch Status:** Pending — Enable authentication (`allow_anonymous false`), generate passwords for authorized clients, and restrict the ACLs to specific user-topic mappings.

---

## 4. Security Operations

**Prevention Steps:**
- Disable anonymous connections by setting `allow_anonymous false` in `mosquitto.conf`.
- Restrict read/write permissions to specific authorized client IDs in `acl`.
- Enforce credential rotation for all system components and enable TLS (Port 8883) with client certificates.
- Set up monitoring to trigger alerts on impossible rate-of-change values on the dashboard application.

**Immediate Actions:**
1. Block attacker source IP: `sudo iptables -A INPUT -s 10.0.5.112 -j DROP`
2. Restart the Mosquitto broker container to clear the malicious retained message: `docker restart mqtt_broker`
3. Configure the password file and ACL rules to block anonymous writes.
4. Notify the security team and initiate the incident response procedure.

---

## 5. Additional Notes

This incident is part of Operation Rogue Solar cyber exercise targeting grid-connected OT telemetry infrastructure. The exploitation of the MQTT broker provides the attacker with write permissions necessary to manipulate operator visibility. Downstream services must be assessed immediately.

**Connected services at risk:**
- Flask Telemetry Dashboard (Port 5000) (displays compromised metrics to operators)

---

## 6. POC (Screenshots)
[Attach screenshots showing the exploit payload, server response, and log evidence]
```

---

## 2. SITREP Report (SITREP)

*This report is used to update leadership on the progress of Red vs. Blue active scenarios.*

```markdown
# SITREP Report (SITREP)

**Cyber Exercise — Operation Rogue Solar**
**Version 1.0**

---

**Date:** [YYYY-MM-DD]
**Time:** [Time of Detection]
**Incident ID:** SITREP-SOLAR-M03

---

## 1. Incident Overview

**Description:**
- Telemetry manipulation/unauthorized publication detected on broker `127.0.0.1:1883`.
- Service affected: Mosquitto MQTT Broker
- Attack vector: Attacker connected anonymously as `rogue_solar_client` and published a forged telemetry payload of `150.00` to the solar topic.
- Attacker successfully exploited the vulnerability; evidence found in `/tmp/mqtt_lab/log/mosquitto.log`.

**Severity Level:** High

**Impact:** The energy dashboard was manipulated to display an inflated photovoltaic generation reading of `150.00 kW` (ground truth was `49.88 kW`), leading to operator blind spots.

**Affected System:** MQTT Broker Container — Mosquitto Service (Port 1883)

---

## 2. Incident Details

**Detection Method:**
Review of `/tmp/mqtt_lab/log/mosquitto.log` reveals unusual request patterns consistent with exploitation. Specific indicators include:

- **IOC:** Unauthorized connection and publish from client `rogue_solar_client` (IP `10.0.5.112`) on topic `grid/solar/site7/kw` with payload `150.00`.

To detect:
```bash
grep -A 1 -i "rogue_solar_client PUBLISH" /tmp/mqtt_lab/log/mosquitto.log
```

**Initial Detection Time:** 2026-06-19 15:38:43 UTC

**Attack Vector:** Anonymous Access & Permissive ACL Wildcard Pattern

---

## 3. Response Actions Taken

**Containment:**
- Block attacker source IP at firewall using `sudo iptables -A INPUT -s 10.0.5.112 -j DROP`.
- Disable anonymous access in `mosquitto.conf` to block further unauthorized publishes.
- Invalidate the current retained message by restarting the broker.

**Eradication:**
- Apply strict ACL file permissions (`user solar_publisher_site7 topic write grid/solar/site7/kw`).
- Enforce credentials for authorized clients and restart services.
- Scan logs for additional indicators of compromise.

**Recovery:**
- Redeploy the MQTT broker with a hardened configuration.
- Re-enable access for the legitimate publisher (`solar_publisher_site7`) using password authentication.
- Monitor `/tmp/mqtt_lab/log/mosquitto.log` for 24 hours post-recovery.

**Lessons Learned:**
- Enforce strict authentication and disable anonymous MQTT access on OT networks.
- Restrict ACL patterns to specific client usernames rather than using wildcards.
- Implement dashboard rate-of-change filters to flag physically impossible jumps.

---

## 4. Technical Analysis

**Evidence:**
- Broker Log: `/tmp/mqtt_lab/log/mosquitto.log`
- Ground Truth Sensor Log: `/tmp/mqtt_lab/log/ground_truth.log`
- Configuration File: `/tmp/mqtt_lab/config/mosquitto.conf`
- ACL File: `/tmp/mqtt_lab/config/acl`

**Indicators of Compromise (IOCs):**
- Connection from client `rogue_solar_client` from IP `10.0.5.112`.
- Telemetry payload value `150.00` published with the retain flag.
- Discrepancy of `+100.12 kW` from physical ground truth in `ground_truth.log`.

**Tactics, Techniques, and Procedures (TTPs):**

**MITRE ATT&CK: T1692.002**
Description: Unauthorized Message: Reporting Message used to gain unauthorised access to the telemetry pipeline. The attacker exploited anonymous access and loose ACL rules to inject a forged reading of `150.00 kW`, mimicking valid power generation.

**Mitigation Recommendations:**
- Set `allow_anonymous false` in `mosquitto.conf`.
- Configure the ACL file with explicit user-level boundaries.
- Set up SIEM alerting for any unauthorized client connections on port 1883.

---

## 5. Communication

**Internal Notification:**
- Security Team: Immediate notification to initiate incident response.
- IT Operations: Coordinate the application of firewall rules and ACL hardening.
- Executive Management: Brief summary of the generation metrics spoofing incident.

**External Notification:**
- Grid Coordination Center: Notify operators that telemetry has been restored and validated.
- Regulatory Bodies: Log the incident report per compliance standards.

**Updates:**
- Frequency: Every 2 hours until containment and hardening are completed.
- Channel: SEC-Ops Slack Channel & Incident Management Portal.

---

## 6. Additional Notes

This incident is part of the Operation Rogue Solar cyber exercise. The exploitation chain demonstrates vulnerability in the protocol validation layers of the OT telemetry grid. All downstream systems must be verified.

---

## 8. POC (Screenshots)
[Attach screenshots of log evidence, attacker IP, and payload]
```

---

## 3. Red Team Incident Report

*This report is submitted by the Red Team upon successful completion of the exploitation objective.*

```markdown
# Red Team Incident Report

**Cyber Exercise — Operation Rogue Solar**
**Version 1.0**

---

**Date/Time:** [YYYY-MM-DD HH:MM:SS]
**Author:** Red Team Lead

---

## 1. Executive Summary

**Objective:**
Gain unauthorized write access to the SCADA telemetry stream and inject a forged photovoltaic generation reading to manipulate operator visibility on the energy dashboard. The target was to inflate the generation reading by at least +50 kW above the physical ground truth.

**MITRE ATT&CK for ICS Mapping:**
- **Tactic:** TA0106 — Impair Process Control
- **Technique:** T1692.002 — Unauthorized Message: Reporting Message

---

## 2. Technical Profile

**Target Broker:** `127.0.0.1:1883` (Mosquitto MQTT)
**Target Topic:** `grid/solar/site7/kw`
**Client ID Used:** `rogue_solar_client`
**Tools Used:** Python (with `paho-mqtt` library) / Bash (`red_attack.py` and `red_attack.sh`)
**Forged Payload Value Published:** `150.00` kW

---

## 3. Execution Narrative

1. **Reconnaissance & Fingerprinting:**
   - Scanned TCP port 1883 using `nmap` and verified the active MQTT broker.
   - Subscribed to the wildcard topic `grid/solar/#` to discover active telemetry streams, noting the regular 10-second updates from `solar_publisher_site7`.
2. **Access Control Analysis:**
   - Identified that the broker accepted anonymous connections (`allow_anonymous true`) and lacked topic-level write restrictions, allowing unauthorized clients to publish to the telemetry topic.
3. **Payload Injection:**
   - Executed `red_attack.py` to connect using the client ID `rogue_solar_client` and published a retained message containing `150.00` to the topic `grid/solar/site7/kw`.

---

## 4. Evidence of Success

**Dashboard Verification:**
- Flask Web Dashboard (Port 5000) reflected the injected value of `150.00 kW`.
- Ground Truth Reference: `49.88 kW`
- Total Discrepancy: `+100.12 kW` (Successfully exceeded the +50 kW scoring threshold)

**Evidence Reference:**
- Broker Log Entry:
  ```text
  Client rogue_solar_client PUBLISH (d0, q0, r1, m0, 'grid/solar/site7/kw', ... (6 bytes))
  Payload: 150.00
  ```

---

## 5. Artifacts Left Behind

Upon execution, the following forensic traces were left in the Mosquitto broker log (`/tmp/mqtt_lab/log/mosquitto.log`):
1. **Connection Event:**
   `New client connected from [Attacker IP] as rogue_solar_client (p2, c1, k60).`
2. **Publication Event:**
   `Client rogue_solar_client PUBLISH (d0, q0, r1, m0, 'grid/solar/site7/kw', ... (6 bytes))`
   `Payload: 150.00`

---

## 6. Scoring Trigger Status

- **Dashboard Exceeded Ground-Truth by Target Amount?** YES
- **Forged Payload Successfully Retained?** YES
```
