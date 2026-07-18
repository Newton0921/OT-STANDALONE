# Blue Team Writeup: Detection & Forensics Walkthrough

This guide details the forensic methodology to identify, investigate, and characterize unauthorized reconnaissance activity targeting a transformer instrumentation Modbus TCP server.

---

## Phase 1: Identifying the Rogue Client IP

1. **Locate the Log File**:
   The Modbus TCP server is configured to log transaction details to `./modbus_server.log`.

2. **Extract and Summarize Client IPs**:
   Use Linux command-line utilities to parse the log and list all unique client IPs that have initiated connection sessions:
   ```bash
   cat ./modbus_server.log | awk -F 'Client: ' '{print $2}' | awk '{print $1}' | sort | uniq -c
   ```
   **Output Analysis**:
   - `192.168.1.10`: Polling at regular intervals (540 records).
   - `192.168.1.99`: Initiated connections but is not part of the standard baseline (4 records).

3. **Cross-Reference with the Whitelist**:
   Read `whitelist.txt` on disk to identify approved engineering workstations or SCADA masters:
   ```bash
   cat whitelist.txt
   ```
   *Result*: Only `192.168.1.10` is listed. Therefore, `192.168.1.99` is flagged as an **unauthorized Modbus client**.

---

## Phase 2: Detecting the First Access Timestamp

To determine when the breach/reconnaissance attempt began, search the log file for the first transaction record originating from the rogue IP:
```bash
grep "Client: 192.168.1.99" ./modbus_server.log | head -n 1
```
*Result*:
```
2026-06-18 10:05:00 - Client: 192.168.1.99 - FC: 1 - Addr: 0 - Qty: 100 - Result: Success
```
The **First Access Timestamp** is **`2026-06-18 10:05:00`**.

---

## Phase 3: Characterizing the Reconnaissance Activity

To analyze how the adversary mapped the system, filter all entries associated with the unauthorized client:
```bash
grep "Client: 192.168.1.99" ./modbus_server.log
```

**Abnormal Read Pattern Analysis**:
1. **Quantity and Address Ranges**:
   - **Baseline Polling (`192.168.1.10`)**: Specifically reads only single registers (`Qty: 1`) at dedicated addresses (`Addr: 5` for Coils, `Addr: 15` for Discrete Inputs, `Addr: 10` for Holding Registers, and `Addr: 25` for Input Registers).
   - **Adversary Activity (`192.168.1.99`)**: Requests large blocks of registers (`Qty: 100`) starting from index 0 (`Addr: 0`). This sweeps the entire standard Modbus address block in single-shot reads.
2. **Function Code Breadth**:
   - The rogue device issued read requests across all four fundamental tables:
     - **FC 1** (Read Coils)
     - **FC 2** (Read Discrete Inputs)
     - **FC 3** (Read Holding Registers)
     - **FC 4** (Read Input Registers)
   - This exhaustive table scan indicates active reconnaissance designed to map the process register space (MITRE ATT&CK for ICS: T0801 - Monitor Process State).

---

## Scoring Criteria Mapping
Ensure you submit the following findings to score points for the Blue Team module:
1. **Source IP**: `192.168.1.99`
2. **Abnormal Read Pattern**: Large-quantity block reads (`Qty: 100`) starting from address 0 across FC01, FC02, FC03, and FC04.
3. **Targeted Register Ranges**: Address `0` to `99` (Quantity `100`) for all four tables.
4. **First Access Timestamp**: `2026-06-18 10:05:00`.

---

## Recommended Remediation & Defenses

1. **Network-Level Whitelisting (Firewalling)**:
   Modbus TCP lacks native authentication. Implement strict firewall rules (iptables/nftables) or network access control lists (ACLs) to drop any traffic on TCP port 5020 (or 5200/502) that does not originate from whitelisted hosts.
   
2. **Industrial Firewalls / Deep Packet Inspection (DPI)**:
   Deploy specialized OT firewalls (e.g., Nozomi, Claroty, or Snort rules) that inspect Modbus packets. Configure alerts or blocks for:
   - Modbus read requests with unexpected quantities (e.g., `Qty > 1`).
   - Requests targeting unmapped addresses.
   - Unauthorized client IPs attempting connection handshakes.

3. **Modbus Gateway / Proxy**:
   Route SCADA telemetry traffic through a secure Modbus TCP gateway that supports authentication and function code restrictions (e.g., mapping read-only views and blocking broad range scans).

4. **Security Information and Event Management (SIEM) Alerting**:
   Ingest Modbus transaction logs into a SIEM and configure behavioral alerts on:
   - Occurrence of new source IPs.
   - High frequency or large quantity of Modbus read commands from any source.
