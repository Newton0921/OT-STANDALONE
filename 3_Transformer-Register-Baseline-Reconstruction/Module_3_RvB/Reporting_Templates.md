# OT Security Incident & Sitrep Reporting Templates

This document contains standard templates for incident response, periodic updates, and threat simulation reporting within the Hacktify OT security lab environment.

---

## 1. Initial Incident Report (INREP) Template

```markdown
# INCIDENT REPORT (INREP)
## IDENTIFIER: INC-[YEAR]-[AUTO_INCREMENT]

* **Incident ID**: INC-XXXX
* **Date / Time**: YYYY-MM-DD HH:MM:SS UTC
* **Reporting Team**: SOC / Blue Team
* **Environment**: 
  - Host System: Ubuntu 22.04 LTS Lab Node
  - Service: Pymodbus TCP Server
  - Industrial Target: Substation Transformer Instrumentation (Load, Oil Temp, Fan, Breaker)
  - Port / Protocol: TCP Port 5020 / Modbus TCP
* **Initial Observation**: 
  [Describe the anomalous traffic pattern or log entries that triggered the investigation, e.g., unexpected read requests mapping broad registers]
* **Suspected Technique**: 
  - MITRE ATT&CK for ICS: T0801 — Monitor Process State
  - Tactic: TA0102 — Discovery
* **Current Status**: 
  [Under Investigation / Contained / Remediated]
```

---

## 2. Situation Report (SITREP) Template

```markdown
# SITUATION REPORT (SITREP)
## STATUS UPDATE FOR INCIDENT: INC-XXXX

* **Incident ID**: INC-XXXX
* **Update #**: [e.g., 01, 02]
* **Timestamp**: YYYY-MM-DD HH:MM:SS UTC

* **Red Team Activity Summary**:
  [Details of the adversary scanning activity, function codes monitored, and registers suspected to be mapped or manipulated]

* **Blue Team Detection Status**:
  [Details of the forensic findings from logs, identification of rogue source IP, access time, and traffic pattern characterization]

* **Scoring Status**:
  * **Red Team Score Card**:
    - Transformer Load Register Address Mapped: [Y/N]
    - Oil Temperature Register Address Mapped: [Y/N]
    - Cooling Fan State Register Address Mapped: [Y/N]
    - Breaker Position Register Address Mapped: [Y/N]
  * **Blue Team Score Card**:
    - Unauthorized Source IP Identified: [Y/N]
    - Abnormal Read Pattern Characterized: [Y/N]
    - Targeted Register Ranges Extracted: [Y/N]
    - First Access Timestamp Audited: [Y/N]

* **Remaining Objectives**:
  [What goals or flags remain to be completed or validated?]

* **Next Steps**:
  1. [Next action item for team, e.g., apply firewall whitelists, reset server context]
  2. [Second action item]
```

---

## 3. Red Team Attack Report Template

```markdown
# RED TEAM THREAT SIMULATION REPORT

* **Objective**: 
  Map the distribution transformer instrumentation register space, distinguish live process parameters from decoy registers, and document the baseline mapping layout.
* **Technique Used**: 
  - MITRE ATT&CK for ICS: T0801 — Monitor Process State
  - Tactic: TA0102 — Discovery
* **Tools Used**: 
  - Pymodbus Client Library (Python 3)
  - Custom script: `red_attack.sh` (sweeps registers 0-99 on FC01, FC02, FC03, and FC04)
* **Enumeration Method**:
  - Scanning function codes FC01 (Coils), FC02 (Discrete Inputs), FC03 (Holding Registers), and FC04 (Input Registers) for registers starting at address 0 with a quantity of 100.
  - Multi-run delta analysis over 20-30 seconds to trace register fluctuation patterns.
* **Steps Performed**:
  1. [Describe step, e.g., discovery of open Port 5020]
  2. [Describe step, e.g., initial sweep run to log non-zero outputs]
  3. [Describe step, e.g., dynamic analysis of fluctuating values vs static decoys]
* **Evidence of Success**:
  - Mapped Process Register Layout:
    1. **Transformer Load (MW)**: [Address] - [Register Type]
    2. **Oil Temperature (C)**: [Address] - [Register Type]
    3. **Cooling Fan State**: [Address] - [Register Type]
    4. **Breaker Position**: [Address] - [Register Type]
* **Artifacts Left Behind**:
  - Log records generated under `./modbus_server.log` originating from adversary testing IP [IP_Address] performing `Qty: 100` read operations.
* **Scoring Trigger**: 
  Successful correlation and compilation of all 4 correct target addresses submitted in the format: `[LoadAddr]-[TempAddr]-[FanAddr]-[BreakerAddr]`.
```
i ll be doing this in caldera for that i need only yaml 
these are the format for the 
# SetupTTP Format

id: [Category]-[TechnologyName]-Setup
name: [Category]-[TechnologyName]-Setup
description: >
  [What is installed/configured, version number, CVEs exposed, 
  ports involved, and what attack surface is enabled.]
tactic: [tactic name]
technique_id: [T####]
technique_name: [Technique Name]
sub_technique: [T####.### or None]
tag: red
service_availability_id: [UUID matching ServiceAvailabilityTTP id]
executors:
  - name: psh
    platform: windows
    command: echo 'Setup Successful'
    payloads: []
    parsers: []


# ServiceAvailabilityTTP Format

id: [UUID — must match service_availability_id in SetupTTP]
name: [Technology Name] Availability Check
description: >
  Verifies [Technology + version] is fully operational via three checks:
  (1) TCP port [XXXX] is bound, (2) [service-name] systemd unit is Active,
  (3) HTTP probe to http://localhost:[XXXX]/ returns a valid code.
  Additionally confirms [secondary port/surface if applicable].
  All checks must pass for SERVICE_STATUS:UP; any failure exits 1.
tactic: execution
technique_id: T1059
technique_name: Command and Scripting Interpreter
sub_technique: T1059.004
tag: service-availability
executors:
  - name: sh
    platform: linux
    command: |
      PORT_UP=$(ss -tlnp 2>/dev/null | grep -q ':[PORT] ' && echo 1 || echo 0); [SECONDARY_PORT_CHECK]; SVC_STATE=$(systemctl is-active [service-name] 2>/dev/null || echo "inactive"); HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 http://localhost:[PORT]/ 2>/dev/null || echo "000"); if [ "$PORT_UP" -ge 1 ] && [ "$SVC_STATE" = "active" ] && { [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "403" ]; }; then echo "SERVICE_STATUS:UP | [SECONDARY_LABEL]:$([ "$[SECONDARY_VAR]" -ge 1 ] && echo OPEN || echo CLOSED)"; else PORT_LABEL=$([ "$PORT_UP" -ge 1 ] && echo "UP" || echo "DOWN"); echo "SERVICE_STATUS:DOWN | PORT:${PORT_LABEL} | SYSTEMD:${SVC_STATE} | HTTP:${HTTP_CODE}"; exit 1; fi
    payloads: []
    parsers: []\

create it acoording to our file