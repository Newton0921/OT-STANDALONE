# Incident Notification Report (INREP)

**Cyber Exercise — Operation GRID GATEWAY**  
**Version 1.0**

---

**Date:** 2026-06-19  
**Time:** 03:15:22  
**Report ID:** IN-GRID-M02  

---

## 1. Current Situation

**Description:**  
The primary substation HMI Webstation (port `10008`) was accessed utilizing active credentials belonging to a deactivated third-party maintenance contractor (`contractor_maint`). The credentials had been left active due to a failure in the account lifecycle de-provisioning workflow after the closure of Work Order 882 on 2026-06-15. The attacker logged in from an external IP `203.0.113.42` and navigated to the restricted `Substation_High_Voltage_Feeder` view (ViewID: 102) to access process controls. Immediate containment and account disabling are required to prevent unauthorized breaker operations on the High-Voltage Feeder.

**Threat Level:** High

**Areas of Concern:**
- Exploitation of retained contractor credentials (`contractor_maint`) allowing unauthorized login access.
- Potential industrial process impact (unauthorized tripping of the feeder breaker) via HMI controls.
- Risk of lateral movement or cascading process disruption across the substation zone.

---

## 2. Threat Intelligence

**Sources:**
- Application Audit Log: `/opt/scada/ScadaWeb/log/ScadaWeb.log`
- CLI Query: `tail -n 100 /opt/scada/ScadaWeb/log/ScadaWeb.log`

**Indicators of Compromise (IOCs):**
- Authentication events for user `contractor_maint` from external IP `203.0.113.42`.
- Log entries displaying unauthorized access to the restricted view `'Substation_High_Voltage_Feeder'` (ViewID: 102).

**Log Entry Identified:**
```
[2026-06-18 03:15:22] INF [contractor_maint] Login successful from 203.0.113.42
[2026-06-18 03:15:22] INF [contractor_maint] Access to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from 203.0.113.42
[2026-06-18 03:15:22] INF [contractor_maint] Dispatched TRIP BREAKER command from 203.0.113.42
[2026-06-18 03:15:22] INF [contractor_maint] Access to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from 203.0.113.42
```

---

## 3. Vulnerability Identification

**Vulnerability:** Retained Valid Credentials / Account De-provisioning Failure (MITRE ATT&CK T0859)

**Affected Parameter:** Login Authentication endpoint and Contractor HMI session routing

**Description:**  
The HMI Webstation authentication database continues to validate credentials for the `contractor_maint` account even after the maintenance project (Work Order 882) has concluded, allowing external threat actors to bypass perimeter authorization check rules.

**Patch Status:** Ongoing — Requiring immediate de-provisioning of `contractor_maint` credentials and restriction of the exposed backup directory on port 8081.

---

## 4. Security Operations

**Prevention Steps:**
- Disable/deactivate the `contractor_maint` account in the Webstation database and Active Directory.
- Enforce network access rules to restrict the internal backup server (`port 8081`) to authorized engineering subnets.
- Implement automated expiry policies on all temporary third-party accounts.
- Enforce Multi-Factor Authentication (MFA) for HMI access.

**Immediate Actions:**
1. Block attacker source IP: `sudo iptables -A INPUT -s 203.0.113.42 -j DROP`
2. Terminate the unsecured Python backup HTTP server on port 8081.
3. Invalidate active sessions and remove the contractor credentials from the HMI configuration.
4. Notify the substation security response lead.

---

## 5. Additional Notes

This incident is part of Operation GRID GATEWAY cyber exercise targeting Eastern Substation. The compromise of HMI credentials allows the attacker to trip physical breakers (`FEEDER_1_CTRL`, etc.). Downstream distribution circuits must be monitored immediately for potential voltage fluctuations.

**Connected services at risk:**
- Downstream high-voltage feeder circuits (potential load-shedding or blackouts).

---

## 6. POC (Screenshots)
[Attach screenshots of HMI logs displaying contractor_maint authentication, and the restricted schematic dashboard]


====================================================================


# SITREP Report (SITREP)

**Cyber Exercise — Operation GRID GATEWAY**  
**Version 1.0**

---

**Date:** 2026-06-19  
**Time:** 03:20:00  
**Incident ID:** SITREP-GRID-M02  

---

## 1. Incident Overview

**Description:**
- Valid account abuse (T0859) detected on HMI Webstation (`127.0.0.1:10008`).
- Service affected: SCADA Webstation Operator Dashboard.
- Attack vector: Authenticated access exploiting retained contractor credentials discovered via an unsecured JSON backup file on port 8081.
- Attacker successfully accessed the restricted control view; evidence found in `/opt/scada/ScadaWeb/log/ScadaWeb.log`.

**Severity Level:** High

**Impact:** Threat actor obtained access to high-voltage feeder diagrams and executed simulated breaker commands.

**Affected System:** Eastern Substation Gateway — Webstation HMI (Port 10008)

---

## 2. Incident Details

**Detection Method:**
Review of the application log file `/opt/scada/ScadaWeb/log/ScadaWeb.log` reveals unauthorized off-hours access. Specific indicators include:

- **IOC:** Audit log entry detailing user `contractor_maint` accessing the restricted view `Substation_High_Voltage_Feeder` at 03:17 AM.

To detect:
```bash
grep -i "contractor_maint" /opt/scada/ScadaWeb/log/ScadaWeb.log
```

**Initial Detection Time:** 2026-06-18 03:15:22

**Attack Vector:** T0859 — Valid Accounts (Account Lifecycle De-provisioning Failure)

---

## 3. Response Actions Taken

**Containment:**
- Isolated the Webstation dashboard from the external network segment.
- Blocked attacker source IP at firewall using `sudo iptables -A INPUT -s 203.0.113.42 -j DROP`.
- Deactivated the contractor account in HMI settings.

**Eradication:**
- Stopped the unsecured backup HTTP server on port 8081 (`sudo kill $(cat /tmp/leak_server.pid)`).
- Purged the backup directory `maint_notes_112.json` to prevent further credential disclosure.

**Recovery:**
- Cleaned and restarted HMI gateway process: `sudo systemctl restart scada-web.service`.
- Monitored `/opt/scada/ScadaWeb/log/ScadaWeb.log` for 24 hours post-incident to verify no recurrence.

**Lessons Learned:**
- Enforce strict IAM policies linking account lifecycles to maintenance ticket closures.
- Disallow hosting of plain-text credentials in backup or public-facing folders.
- Enable automatic audit alerting for off-hours access to HMI controls.

---

## 4. Technical Analysis

**Evidence:**
- Log file: `/opt/scada/ScadaWeb/log/ScadaWeb.log`
- Leaked JSON file: `/var/www/html/backup/maint_notes_112.json`

**Indicators of Compromise (IOCs):**
- Anomalous login at 03:15:22 AM.
- Access to restricted ViewID 102.
- Session originating from public subnet IP `203.0.113.42`.

**Tactics, Techniques, and Procedures (TTPs):**

**MITRE ATT&CK: T0859 (Valid Accounts) / TA0110 (Persistence)**
Description: Threat actor leveraged active credentials of a closed contractor work order (`contractor_maint`) to authenticate to the SCADA interface, achieving unauthorized access to the High-Voltage Feeder controls.

**Mitigation Recommendations:**
- Implement role-based access controls (RBAC) to restrict access to breaker controls.
- Audit Active Directory regularly for stagnant vendor accounts.
- Implement network segmentation between business IT networks and OT zones.

---

## 5. Communication

**Internal Notification:**
- Security Operations Center (SOC): Initiated containment playbooks.
- Substation Engineering Team: Advised to monitor physical grid metrics.
- Plant Manager: Briefed on incident severity.

**External Notification:**
- Compliance regulator: Report submitted per OT security reporting guidelines.

**Updates:**
- Frequency: Every 2 hours during resolution phase.
- Channel: Secure Internal Engineering Chat.

---

## 6. Additional Notes

This incident is part of Operation GRID GATEWAY cyber exercise.

---

## 7. Submission

**Prepared By:** Blue Team Analyst

---

## 8. POC (Screenshots)
[Attach screenshots of ScadaWeb.log entries and the active iptables drop rules]


====================================================================


# Red Team Incident Report (Red Report)

**Cyber Exercise — Operation GRID GATEWAY**  
**Version 1.0**

---

**Date:** 2026-06-19  
**Report ID:** RED-GRID-M02  
**Target:** Eastern Substation Gateway (Rapid SCADA HMI)  

---

## 1. Executive Summary

**Objective:**  
To test the resilience of the Eastern Substation OT gateway controls by locating leaked access credentials and demonstrating how an unauthorized external entity could utilize leftover valid contractor credentials (MITRE ICS T0859) to compromise substation monitoring systems.

**Key Accomplishments:**  
- Located an unsecured backup web instance hosting plain-text maintenance credentials.  
- Authenticated successfully to the SCADA Webstation HMI on port `10008` as `contractor_maint`.  
- Accessed the restricted substation physical feeder layout and monitored live telemetry.  

---

## 2. Attack Lifecycle & Technical Steps

### Step 1: Enumeration & Reconnaissance (T0809 / T0843)
- Scanned the target network segment and identified an open HTTP server on port `8081`.
- Performed directory brute-forcing and identified a publicly accessible backup directory: `/backup/maint_notes_112.json`.

### Step 2: Credential Extraction (T0860)
- Read `/backup/maint_notes_112.json` and retrieved credentials for the third-party contractor account:
  - **Username:** `contractor_maint`
  - **Password/Token:** MD5 Hash `133987b0b6ad0c01fc0ccbdae1b95449` (cracked to recover password `Welcome123`)

### Step 3: Access & Authentication (T0859)
- Connected to the primary Webstation HMI (`http://127.0.0.1:10008`) and successfully authenticated using the extracted contractor credentials.

### Step 4: Lateral Movement / Substation Access (TA0109)
- Navigated to the restricted view `/Substation_High_Voltage_Feeder` (ViewID: 102), demonstrating access to live voltage, frequency, and breaker status controls.

---

## 3. Indicators of Compromise (IOCs) Generated

- **Attacker Source IP:** `203.0.113.42` (Simulated external source IP)
- **Authenticating Account:** `contractor_maint`
- **Request Log Entries:**
  ```
  [2026-06-18 03:15:22] INF [contractor_maint] Login successful from 203.0.113.42
  [2026-06-18 03:15:22] INF [contractor_maint] Access to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from 203.0.113.42
  [2026-06-18 03:15:22] INF [contractor_maint] Dispatched TRIP BREAKER command from 203.0.113.42
  [2026-06-18 03:15:22] INF [contractor_maint] Access to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from 203.0.113.42
  ```

---

## 4. Remediation Recommendations

1. **Implement AD Account Expiry Policies:** Enforce automatic lockouts or temporary windows on contractor accounts linked to Work Order closure times.
2. **Secure Configuration/Backup Repositories:** Restrict port `8081` access or enforce strong authentication on configuration folders.
3. **Multi-Factor Authentication (MFA):** Require multi-factor authentication for any logins targeting the HMI interface.

