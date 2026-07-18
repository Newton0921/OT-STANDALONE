# Incident Reporting Templates

This document contains standard reporting templates for both Red and Blue team operators participating in the Hidden Load-Shed Timer challenge.

---

## 1. Incident Notification Report (INREP)

*This report is submitted by the Blue Team immediately upon identifying initial anomalous behavior.*

```markdown
# Incident Notification Report (INREP)

**Cyber Exercise — Operation VAJRA SHAKTI**
**Version 1.0**

---

**Date:** [YYYY-MM-DD]
**Time:** [Time of Incident]
**Report ID:** IN-VAJRA-M03

---

## 1. Current Situation

**Description:** The primary programmable logic controller (OpenPLC Runtime running on `openplc_blue` at `http://localhost:8080`) was compromised due to unauthorized access utilizing default administrative credentials. The attacker modified the active program logic, replacing the baseline with a Structured Text program (`active_malicious.st`) containing a hidden timer routine. This timer targets the `%QX0.2` coil (`FEEDER_3_CMD`), forcing it to drop to `FALSE` (trip) every 60 seconds. Immediate investigation and containment are required.

**Threat Level:** High

**Areas of Concern:**
- Exploitation of `openplc` default web console credentials allowing unauthorised access to privileged functionality
- Potential credential reuse or lateral network movement from the engineering workstation enabling pivot risk
- Risk of cascading compromise across the Substation Zero industrial network segment

---

## 2. Threat Intelligence

**Sources:**
- Application Log: `/docker_persistent/openplc_audit.log`
- CLI Query: `podman exec openplc_blue cat /docker_persistent/openplc_audit.log`

**Indicators of Compromise (IOCs):**
- System logs containing: `SYSTEM: active_program.st overwritten via WebAPI`
- System logs containing: `SYSTEM: OpenPLC Runtime Restart Triggered`

**Log Entry Identified:**
```text
[WARN] 2026-06-19 11:42:31 - SYSTEM: active_program.st overwritten via WebAPI
[INFO] 2026-06-19 11:42:31 - SYSTEM: OpenPLC Runtime Restart Triggered
```

---

## 3. Vulnerability Identification

**Vulnerability:** Insecure default credentials (CWE-1188) combined with unauthorized program execution (T0889)

**Affected Parameter:** `/upload-program` endpoint

**Description:** OpenPLC Runtime processes the `/upload-program` endpoint without sufficient sanitisation or security controls, allowing an attacker to manipulate the application logic and access privileged data or functionality.

**Patch Status:** Ongoing — local administrator password rotation + network segmentation

---

## 4. Security Operations

**Prevention Steps:**
- Rotate the default admin dashboard credentials (`openplc` / `openplc`) via Settings
- Restrict port 8080 to authorized engineering workstation IPs only via firewall rules
- Enforce file integrity monitoring (FIM) on compiled Structured Text binaries
- Segment the OT web dashboard network from public segments
- Enforce security code reviews prior to uploading new Structured Text project files
- Implement least-privilege network access controls on the engineering workstation segment

**Immediate Actions:**
1. Block attacker source IP: `iptables -A INPUT -s 10.10.50.15 -j DROP`
2. Rotate any credentials exposed by this compromise
3. Invalidate all active sessions on the affected service
4. Notify the security team and initiate the incident response procedure

---

## 5. Additional Notes

This incident is part of Operation VAJRA SHAKTI cyber exercise targeting Substation Zero. The exploitation of `openplc_blue` provides the attacker with control access necessary to progress to the next machine in the kill chain. Downstream services must be assessed immediately.

**Connected services at risk:**
- Downstream distribution circuits fed by Feeder 3 (potential voltage fluctuations or blackout risk)

---

## 6. POC (Screenshots)
[Attach screenshots showing the exploit payload, server response, and log evidence]
```

---

## 2. SITREP Report (SITREP)

*This report is used to update leadership on the progress of Red vs. Blue active scenarios.*

```markdown
# SITREP Report (SITREP)

**Cyber Exercise — Operation VAJRA SHAKTI**
**Version 1.0**

---

**Date:** [YYYY-MM-DD]
**Time:** [Time of Detection]
**Incident ID:** SITREP-VAJRA-M03

---

## 1. Incident Overview

**Description:**
- Logic Modification Attack (T0889) detected on machine `openplc_blue` (`http://localhost:8080`)
- Service affected: OpenPLC Web Dashboard
- Attack vector: Authenticated project upload via Web API using default credentials, replacing the active controller configuration
- Attacker successfully exploited the vulnerability; evidence found in `/docker_persistent/openplc_audit.log`

**Severity Level:** High

**Impact:** Feeder 3 `%QX0.2` (`FEEDER_3_CMD`) is periodically driven to `FALSE` (tripped state) for one execution cycle every 60 seconds.

**Affected System:** `openplc_blue` — OpenPLC Runtime (Port 8080)

---

## 2. Incident Details

**Detection Method:**
Review of application log `/docker_persistent/openplc_audit.log` reveals unusual request patterns consistent with exploitation. Specific indicators include:

- **IOC:** Audit log message: `SYSTEM: active_program.st overwritten via WebAPI` followed by runtime restart.

To detect:
```bash
podman exec openplc_blue cat /docker_persistent/openplc_audit.log | grep -E "overwritten|Restart"
```

**Initial Detection Time:** 2026-06-19 11:42:31

**Attack Vector:** T0889 — Modify Program

---

## 3. Response Actions Taken

**Containment:**
- Isolate `openplc_blue` container from non-engineering network segments
- Block attacker source IP at perimeter firewall using `iptables -A INPUT -s 10.10.50.15 -j DROP`
- Revoke any exposed default admin credentials immediately
- Invalidate all active sessions on the affected service

**Eradication:**
- Patch the identified vulnerability (see Mitigation Recommendations)
- Rotate all credentials exposed during this incident
- Review logs for additional compromise indicators on connected systems

**Recovery:**
- Redeploy service from clean configuration after patching by copying baseline program:
  `podman cp ./investigation/baseline.st openplc_blue:/docker_persistent/st_files/baseline.st`
- Re-enable access only after patch verification and admin password change
- Monitor `/docker_persistent/openplc_audit.log` for 2 hours post-recovery for recurrence

**Lessons Learned:**
- Enforce custom credentials on first initialization of OpenPLC instances
- Maintain cryptographic hash list and out-of-band backups of all compiled ST files
- Implement strict VLAN segmentation of OT web consoles
- Enforce runtime integrity verification on loaded Structured Text projects

---

## 4. Technical Analysis

**Evidence:**
- `/docker_persistent/openplc_audit.log`
- `/docker_persistent/st_files/active_program.st`
- Active program SHA-256 hash: `a2672a4c1c423405d20f9e3c5b550caac07d67af821f6a921ea1545819c61c9d`

**Indicators of Compromise (IOCs):**
- Unexpected log message: `SYSTEM: active_program.st overwritten via WebAPI`
- High volume of read/write connections to port 8080 from unauthorized IPs
- Registry value of output `%QX0.2` periodically dropping to `FALSE` in Modbus TCP communications

**Tactics, Techniques, and Procedures (TTPs):**

**MITRE ATT&CK: T0889**
Description: Modify Program used to gain unauthorised access to OpenPLC Runtime. The attacker exploited insecure default credentials to upload a modified ST program containing a hidden load-shedding timer, achieving persistence and initiating recurring feeder trips.

**Mitigation Recommendations:**
- Apply secure credentials configuration fix for OpenPLC dashboard (rotate default passwords on setup)
- Implement code-signing or file integrity checks across all controller program loads
- Enable structured logging and SIEM alerting for web dashboard configurations
- Conduct security config audit of all plant floor devices and interface consoles
- Implement firewall ACLs to block port 8080 access from standard business subnets

---

## 5. Communication

**Internal Notification:**
- Security Team: Immediate notification to initiate incident response
- IT Operations: Coordinate firewall rules and container isolation
- Executive Management: Timely notification with impact summary
- Legal & Compliance: Notification if regulatory critical infrastructure outage reporting thresholds are met

**External Notification:**
- CERT-In: Notification per mandatory OT security incident reporting requirements
- Affected downstream services: Notify teams managing circuits connected to Feeder 3

**Updates:**
- Frequency: Every 2 hours until containment confirmed
- Channel: Internal Incident Response channels + CISO escalation channel

---

## 6. Additional Notes

This incident is part of Operation VAJRA SHAKTI cyber exercise. The exploitation chain continues through connected systems — all downstream services must be assessed for impact.

---

## 7. Submission

**Prepared By:** Blue Team Analyst

---

## 8. POC (Screenshots)
[Attach screenshots of log evidence, attacker IP, and payload]
```
