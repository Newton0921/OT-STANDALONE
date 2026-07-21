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
<img width="936" height="147" alt="image" src="https://github.com/user-attachments/assets/d236f936-c32d-40e3-8d35-670a02a01d41" />

     *These log entries represent daytime hours, originating from internal substation subnet ranges.*
   * Identify the anomalous, off-hours entries:
<img width="1067" height="142" alt="image" src="https://github.com/user-attachments/assets/ee643f07-8b5d-46ba-a579-0269da7bb606" />

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
   <img width="765" height="72" alt="image" src="https://github.com/user-attachments/assets/dc2dbffc-be1e-49d6-ac76-c09cc22f3be4" />

2. View the closed work order file:
   ```bash
   cat /var/log/substation_maintenance/work_order_882_CLOSED.txt
   ```
   **File Content:**
<img width="797" height="166" alt="image" src="https://github.com/user-attachments/assets/138259d0-0169-4c1b-ab9a-0f27f436967d" />

3. **Correlate the Timeline:**
   * **Work Order Closure:** The high-voltage feeder maintenance was officially completed and closed on **2026-06-15**.
   * **System Access Event:** The `contractor_maint` account logged in and accessed the HMI on **2026-06-18** (3 days *after* the maintenance window had closed).
4. **Identify the Policy Failure (Artifact 5):**
   * **Account De-provisioning Failure (MITRE ATT&CK T0859):** The IAM policy failed to disable/de-provision the third-party contractor credentials immediately upon closure of Work Order 882.

---


1. **Immediate Threat Containment:**
   * Disable/lock the `contractor_maint` account in the Webstation database and Active Directory.
   * Terminate any active sessions associated with the `contractor_maint` identity.
   * Block the malicious IP `203.0.113.42` at the perimeter firewall.
2. **Identity & Access Management (IAM) Hardening:**
   * Establish automated expiration dates for temporary contractor accounts aligned with their maintenance windows.
   * Require Multi-Factor Authentication (MFA) for all HMI logins, especially for remote access.
3. **Log & Telemetry Enhancements:**
   * Set up SIEM alerts for any off-hours SCADA HMI access attempts.
   * Configure alerting rules for access from non-standard subnets.
