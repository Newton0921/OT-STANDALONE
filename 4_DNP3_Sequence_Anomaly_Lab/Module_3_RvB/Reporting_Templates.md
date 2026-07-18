# Incident Reporting Templates

This document contains standard templates for industrial cybersecurity incident response reporting. These are designed to align with SANS ICS515 and CISA ICS-CERT incident reporting guidelines.

---

## 1. Initial Incident Report (INREP)

```text
================================================================================
                    INITIAL INCIDENT REPORT (INREP)
================================================================================
Incident ID:          INC-2026-DNP3-001
Date/Time:            2026-06-19 16:09:13 UTC
Reporting Team:       Blue Team Alpha / Security Operations Center
--------------------------------------------------------------------------------
Environment Profile:
  - Protocol:         DNP3 (Distributed Network Protocol v3) over TCP
  - Network Port:     TCP 20000 (Substation Feeder Link)
  - Asset Targeted:   OpenDNP3 Outstation (Substation RTU)
  - Process Output:   Feeder Breaker Control (Binary Output CROB - Index 7)
--------------------------------------------------------------------------------
Initial Observation:
  SCADA HMI telemetry indicated an uncommanded feeder breaker state change from 
  CLOSED to OPEN at 16:09:13 UTC, causing a localized load shed. The outstation 
  reported a control action without a preceding Select command, coming from an 
  unrecognized master link address.

Suspected Technique:
  - MITRE ATT&CK for ICS: T1692.001 - Unauthorized Message: Command Message
  - MITRE ATT&CK for ICS Tactic: TA0106 - Impair Process Control

Current Status:
  The Feeder Breaker remains in the OPEN state. Active control operations 
  from SCADA Master 1 have resumed to verify status. Forensic system logs and 
  PCAP capture files have been secured and archived.
================================================================================
```

---

## 2. Situation Report (SITREP)

```text
================================================================================
                         SITUATION REPORT (SITREP)
================================================================================
Incident ID: INC-2026-DNP3-001  |  Update #: 01  |  Timestamp: 2026-06-19 16:25:00
--------------------------------------------------------------------------------
1. RED PARTICIPANT ACTIVITY SUMMARY
   The attacker utilized an unauthorized master station (DNP3 Address 66) to transmit 
   a Direct Operate (Function Code 3) command frame directly targeting the Control 
   Relay Output Block (Object 12, Variation 1) on Point Index 7. This bypassed the 
   Select-Before-Operate (SBO) safety sequence enforced on normal commands, forcing 
   an immediate transition.

2. BLUE PARTICIPANT DETECTION STATUS
   Forensic analysis of /opt/dnp3_lab/logs/dnp3_protocol.log identified the 
   unauthorized command transaction executing at 16:09:13. Comparison with the 
   whitelist.txt verified that Master Address 66 is unauthorized. PCAP analysis 
   of dnp3_traffic.pcap validated the sequence violation (FC 3 sent from source 
   address 66 without a preceding FC 1 Select frame).

3. SCORING STATUS
   * Red Team Score Trigger:
     - Feeder breaker state changed via Direct Operate without Select: YES

   * Blue Team Score Trigger:
     - Unlisted source address identified:                      YES (Address: 66)
     - Function code sequence anomaly identified:               YES (FC: 3)
     - Targeted binary output point index identified:           YES (Index: 7)
     - Sequence violation classification documented:           YES (Direct Operate)
     - Process state change timestamp/resulting state verified: YES (16:09:13 / OPEN)

4. REMAINING OBJECTIVES | NEXT STEPS
   - [ ] Implement firewall filters to drop DNP3 traffic not originating from SCADA Master 1 (10.0.0.50).
   - [ ] Reconfigure the outstation database stack to enforce stateful Select-Before-Operate (SBO) on Point Index 7.
   - [ ] Upgrade the outstation and SCADA Master to use DNP3 Secure Authentication (SAv5) to cryptographically validate commands.
================================================================================
```

---

## 3. Red Team Adversarial Report (Red Report)

```text
================================================================================
                    RED TEAM ADVERSARIAL REPORT (Red Report)
================================================================================
Objective:
  Demonstrate unauthorized process control impairment on the feeder breaker by 
  bypassing the outstation's Select-Before-Operate configuration.

Technique:
  - MITRE ATT&CK for ICS: T1692.001 - Unauthorized Message: Command Message
  - MITRE ATT&CK for ICS Tactic: TA0106 - Impair Process Control

Tools Used:
  - Custom DNP3 Frame Construction Script (red_attack.sh)
  - Nmap (Service Discovery)

Parameters Used:
  - Target Outstation IP/Port:  127.0.0.1:20000
  - Master Address Used:        66 (Unlisted)
  - Outstation Address:         10
  - Point Index Targeted:       7 (Feeder Breaker)
  - Control Action:             Latch On (Trip Breaker)

Steps Summary:
  1. Performed service discovery on target port TCP 20000.
  2. Crafted a raw DNP3 Link Layer and Application Layer frame.
  3. Set Link Layer header source address to 66 (unlisted) and destination to 10.
  4. Configured Application Layer Function Code to 3 (Direct Operate) on Object 
     12 Variation 1 Index 7, bypassing the Select (FC1) prerequisite.
  5. Executed script to transmit frame and monitored outstation response.

Evidence of Success:
  - Breaker State Change:       YES
  - State Change Timestamp:     2026-06-19 16:09:13
  - Outstation Response:        Success ACK received.

Artifacts Remaining:
  - Protocol Log:               Entry showing FC: 3 (Direct Operate) from Address 66.
  - PCAP:                       Single TCP frame sent to port 20000 containing the raw 
                                DNP3 payload.

Scoring Trigger:
  - Feeder breaker state transitioned from CLOSED to OPEN using Direct Operate (FC3) 
    without a preceding Select frame (FC1) from Master Address 66: CONFIRMED
================================================================================
```
