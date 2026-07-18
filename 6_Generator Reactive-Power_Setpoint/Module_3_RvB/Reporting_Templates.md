# Incident Reporting Templates

This document contains standard reporting templates for both Red and Blue team operators participating in the Generator Reactive-Power Setpoint challenge.

---

## 1. Incident Notification Report (INREP)

*This report is submitted by the Blue Team immediately upon identifying initial anomalous behavior.*

```markdown
# Incident Notification Report (INREP)

**Cyber Exercise — Operation VAJRA SETPOINT**
**Version 1.0**

---

**Date:** [YYYY-MM-DD]
**Time:** [Time of Incident]
**Report ID:** IN-SETPOINT-M03

---

## 1. Current Situation

**Description:** The primary generator voltage-control server (OPC UA Server running on port 4840) was compromised due to unauthorized parameter modification. The attacker connected anonymously and wrote an out-of-policy value of `75.0` Mvar to the `ReactivePowerSetpoint` node (`ns=2;i=5`), which exceeds the approved operating band (5.0 to 15.0 Mvar). This triggered a critical `DeviationAlarm` and halted the process. Immediate investigation and containment are required.

**Threat Level:** High

**Areas of Concern:**
- Exploitation of anonymous write permissions on OPC UA nodes allowing unauthorised parameter manipulation.
- Potential physical equipment damage or grid instability due to unauthorized reactive-power setpoint adjustments.
- Risk of cascading process alarms and automatic safety shutdowns of the generation unit.

---

## 2. Threat Intelligence

**Sources:**
- Application Session Log: `session_log.txt`
- Write Event Log: `write_event_log.txt`
- Process Alarm Log: `process_alarm_log.txt`

**Indicators of Compromise (IOCs):**
- Anonymous session open from unauthorized IP `10.10.10.100` (SessionID: `ns=1;i=105`).
- Write event log entries indicating modification of NodeID `ns=2;i=5` from `10.0` to `75.0`.
- Process alarm logs displaying a `DeviationAlarm` with value `75.0` breaching approved thresholds.

**Log Entry Identified:**
```text
[2026-06-18T10:22:45.123456] SESSION OPEN | SessionID: ns=1;i=105 | IP: 10.10.10.100 | Token: Anonymous
[2026-06-18T10:22:45.123456] WRITE EVENT | SessionID: ns=1;i=105 | NodeID: ns=2;i=5 | OldValue: 10.0 | NewValue: 75.0
[2026-06-18T10:22:45.123456] ALARM | Type: DeviationAlarm | NodeID: ns=2;i=5 | ThresholdBreached: OUT OF BAND | AlarmValue: 75.0
```

---

## 3. Vulnerability Identification

**Vulnerability:** Insecure Anonymous Write Access (CWE-284) combined with unauthorized parameter modification (T0836)

**Affected Parameter:** NodeID `ns=2;i=5` (`ReactivePowerSetpoint`)

**Description:** The OPC UA server processes write commands to the `ReactivePowerSetpoint` node without enforcing authentication, allowing anonymous connections to modify critical process parameters.

**Patch Status:** Pending — Disabling anonymous write permissions + enforcing input range validation limits.

---

## 4. Security Operations

**Prevention Steps:**
- Disable anonymous write capability on the OPC UA server.
- Restrict read/write privileges on setpoint nodes to authenticated engineering roles only.
- Implement server-side validation to reject setpoint values outside the 5.0 to 15.0 Mvar band.
- Restrict TCP port 4840 access to authorized engineering workstations using network firewalls.
- Enable centralized logging and SIEM alerts for anonymous OPC UA connections.

**Immediate Actions:**
1. Block attacker source IP: `iptables -A INPUT -s 10.10.10.100 -j DROP`
2. Restart the OPC UA server and revert the setpoint value to `10.0` Mvar.
3. Configure the server to reject anonymous write commands.
4. Notify the security team and initiate the incident response procedure.

---

## 5. Additional Notes

This incident is part of Operation VAJRA SETPOINT cyber exercise targeting generation asset voltage controls. The exploitation of the OPC UA interface provides the attacker with parameter write access necessary to disrupt the physical generation process. Downstream voltage regulators and distribution grids are at risk.

**Connected services at risk:**
- Downstream voltage regulators and distribution substation circuits.

---

## 6. POC (Screenshots)
[Attach screenshots showing the exploit payload, server response, and log evidence]
```

---

## 2. SITREP Report (SITREP)

*This report is used to update leadership on the progress of Red vs. Blue active scenarios.*

```markdown
# SITREP Report (SITREP)

**Cyber Exercise — Operation VAJRA SETPOINT**
**Version 1.0**

---

**Date:** [YYYY-MM-DD]
**Time:** [Time of Detection]
**Incident ID:** SITREP-SETPOINT-M03

---

## 1. Incident Overview

**Description:**
- Parameter Modification Attack (T0836) detected on machine `generator_control_server` (`opc.tcp://127.0.0.1:4840/`)
- Service affected: OPC UA Control Interface
- Attack vector: Anonymous write operation on the reactive-power setpoint node `ns=2;i=5`
- Attacker successfully exploited the vulnerability; evidence found in `session_log.txt` and `write_event_log.txt`

**Severity Level:** High

**Impact:** ReactivePowerSetpoint was changed from `10.0` to `75.0` Mvar, triggering a `DeviationAlarm` and halting the voltage-control loop.

**Affected System:** OPC UA Server (Port 4840)

---

## 2. Incident Details

**Detection Method:**
Review of `session_log.txt`, `write_event_log.txt`, and `process_alarm_log.txt` reveals unauthorized anonymous parameter write operations. Specific indicators include:

- **IOC:** SessionID `ns=1;i=105` established anonymously from IP `10.10.10.100` writing `75.0` to `ns=2;i=5`.

To detect:
```bash
grep -E "Anonymous|WRITE EVENT|DeviationAlarm" *_log.txt
```

**Initial Detection Time:** 2026-06-18 10:22:45 UTC

**Attack Vector:** T0836 — Modify Parameter (Anonymous Access)

---

## 3. Response Actions Taken

**Containment:**
- Block attacker source IP at firewall using `iptables -A INPUT -s 10.10.10.100 -j DROP`.
- Disable anonymous write privileges on the OPC UA server configuration.
- Revert the `ReactivePowerSetpoint` value to the safe baseline of `10.0` Mvar.

**Eradication:**
- Hardened server configurations to enforce username/password validation on OPC UA client sessions.
- Applied input range validation bounds (5.0 to 15.0 Mvar) directly inside the OPC UA server code.
- Reviewed logs for any additional unauthorized connections or parameter manipulations.

**Recovery:**
- Restarted the OPC UA server process under a hardened configuration.
- Verified that the setpoint value remains locked at `10.0` Mvar under baseline conditions.
- Monitored process logs for 2 hours post-recovery to ensure stability.

**Lessons Learned:**
- Never expose writable OPC UA nodes anonymously.
- Implement strict range validation on all setpoints at the server/PLC code layer.
- Enforce network ACLs to limit OPC UA port 4840 to authorized PLC programming terminals.

---

## 4. Technical Analysis

**Evidence:**
- `session_log.txt`
- `write_event_log.txt`
- `value_change_log.txt`
- `process_alarm_log.txt`

**Indicators of Compromise (IOCs):**
- Anonymous session `ns=1;i=105` from source IP `10.10.10.100`.
- Write event modifying Node ID `ns=2;i=5` from `10.0` to `75.0` Mvar.
- Process alarm of type `DeviationAlarm` triggered.

**Tactics, Techniques, and Procedures (TTPs):**

**MITRE ATT&CK: T0836**
Description: Modify Parameter used to manipulate the generator reactive-power setpoint. The attacker connected anonymously via OPC UA, located the writable setpoint node `ns=2;i=5`, and updated its value to `75.0` Mvar, inducing process deviation.

**Mitigation Recommendations:**
- Enforce authentication on all OPC UA server connection endpoints.
- Apply strict access levels on variables, disabling anonymous write permissions.
- Validate parameter values against approved operational thresholds before applying writes.

---

## 5. Communication

**Internal Notification:**
- Security Team: Incident response initiated immediately.
- Grid Operations: Advised of generation unit deviation and safe rollback to baseline.
- Plant Management: Notified of process containment status.

**External Notification:**
- Regulatory Bodies: Logged incident report per industrial critical infrastructure guidelines.

**Updates:**
- Frequency: Every 2 hours until the hardened configuration is verified and stable.
- Channel: Plant Operations SEC-Ops channel.

---

## 6. Additional Notes

This incident is part of the Operation VAJRA SETPOINT cyber exercise. The vulnerability path highlights the critical risk of insecure default access permissions on telemetry and control protocols.

---

## 7. Submission

**Prepared By:** Blue Team Analyst

---

## 8. POC (Screenshots)
[Attach screenshots of log evidence, attacker IP, and payload]
```
