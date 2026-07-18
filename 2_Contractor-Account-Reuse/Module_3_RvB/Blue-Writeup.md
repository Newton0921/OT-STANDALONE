# Blue Team Walkthrough: Contractor Account Reuse in the Control Room

## Objective
Investigate anomalous off-hours activity flagged on the substation HMI Webstation. Correlate raw HMI logs against physical maintenance logs to identify the compromised account, the source IP, the exact timeline of unauthorized actions, and the root-cause policy failure.

## Target Artifacts for Investigation
To score 100% on the Blue Team side, you must answer the following 5 analytical questions:
1. **Identified Contractor Account:** The exact username used to authenticate.
2. **Attacker Source IP Address:** The IP address from which the anomalous login originated.
3. **Off-hours Timestamp:** The date and time when the unauthorized session was established.
4. **Restricted View/Channel Accessed:** The specific system view or resource ID requested.
5. **Root-Cause Policy Failure:** Why the attacker was able to log in.

---

## Detailed Forensic Investigation Walkthrough

### Step 1: Log Acquisition & Analysis
1. Navigate to the Rapid SCADA Webstation application log directory:
   ```bash
   cd /opt/scada/ScadaWeb/log/
   ```
2. View the system audit log file `ScadaWeb.log` to inspect authentication and navigation events:
   ```bash
   cat ScadaWeb.log
   ```
3. **Analyze the Logs:**
   * Look for normal operator/engineer login profiles. You will see authorized activity:
     ```
     [2026-06-17 08:00:12] INF [Operator1] Login successful from 192.168.1.50
     [2026-06-17 09:15:00] INF [Engineer1] Login successful from 192.168.1.51
     ```
     *These log entries represent daytime hours, originating from internal substation subnet ranges.*
   * Identify the anomalous, off-hours entries:
     ```
     [2026-06-18 03:15:22] INF [contractor_maint] Login successful from 203.0.113.42
     [2026-06-18 03:15:22] INF [contractor_maint] Access to view 'Substation_High_Voltage_Feeder' (ViewID: 102) from 203.0.113.42
     [2026-06-18 03:15:22] INF [contractor_maint] Dispatched TRIP BREAKER command from 203.0.113.42
     ```
4. **Key Forensic Findings (Artifacts 1, 2, 3, 4):**
   * **Compromised Account:** `contractor_maint`
   * **Source IP Address:** `203.0.113.42` (An external/unrecognized IP outside the internal 192.168.1.x subnet).
   * **Login Timestamp:** `2026-06-18 03:15:22` (Anomalous, off-hours activity at 03:15 AM).
   * **Resource Accessed:** View `Substation_High_Voltage_Feeder` (ViewID: `102`), which is a critical control interface.

### Step 2: Correlating with Substation Maintenance Records
To determine if this access was legitimate, correlate the timestamp with active maintenance work orders.
1. Inspect the local substation maintenance work order directory:
   ```bash
   ls -la /var/log/substation_maintenance/
   ```
2. View the closed work order file:
   ```bash
   cat /var/log/substation_maintenance/work_order_882_CLOSED.txt
   ```
   **File Content:**
   ```
   WORK ORDER: 882
   SYSTEM: Substation High Voltage Feeder (SUB_115K_HV)
   TECHNICIAN: contractor_maint
   ROLE: Maintenance Contractor (3rd Party — PowerServ Ltd)
   STATUS: CLOSED
   START_DATE: 2026-06-13
   END_DATE:   2026-06-15
   REVIEWED_BY: Engineer1
   NOTES: Physical HV feeder inspection complete. System returned to operational.
   AD_DEPROVISIONING: PENDING — contractor_maint account NOT yet disabled as of 2026-06-18.
   ```
3. **Correlate the Timeline:**
   * **Work Order Closure:** The high-voltage feeder maintenance was officially completed and closed on **2026-06-15**.
   * **System Access Event:** The `contractor_maint` account logged in and accessed the HMI on **2026-06-18** (3 days *after* the maintenance window had closed).
4. **Identify the Policy Failure (Artifact 5):**
   * **Account De-provisioning Failure (MITRE ATT&CK T0859):** The IAM policy failed to disable/de-provision the third-party contractor credentials immediately upon closure of Work Order 882.

### Step 3: Running the Automated Detection Script
The Blue module includes a detection scoring script:
```bash
sudo bash blue_detect.sh
```
This script automatically checks all 5 scoring criteria and outputs a BLUE TEAM DETECTION SCORE out of 5.

---

## Five Scoring Criteria — Summary

| # | Criterion | Finding |
|---|-----------|---------|
| 1 | Contractor account used | `contractor_maint` |
| 2 | Source IP of anomalous login | `203.0.113.42` |
| 3 | Login timestamp (off-hours) | `2026-06-18 03:15:22` |
| 4 | Restricted channel accessed | `Substation_High_Voltage_Feeder` (ViewID: 102) |
| 5 | Policy failure | Account NOT disabled after Work Order 882 closed (2026-06-15) |

---

