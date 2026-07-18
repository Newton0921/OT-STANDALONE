# Challenge: Contractor Account Reuse - Red vs Blue Scenario

## Scenario Overview
This module simulates a live-action **Red vs. Blue (RvB)** exercise focusing on **MITRE ATT&CK for ICS Technique T0859 (Valid Accounts)**.
A regional electrical substation was recently serviced by a third-party contractor who had local/remote access to the HMI. The contractor's work order has been marked CLOSED, but due to a failure in the Active Directory de-provisioning workflow, the account remains enabled.

* **Red Team's Goal:** Discover the leaked contractor credentials via an unsecured development server, log into the Webstation HMI, and execute unauthorized breaker controls on the High-Voltage Feeder.
* **Blue Team's Goal:** Detect the unauthorized login, identify the compromised account and source IP, correlate the action against physical maintenance records, and remediate the threat by disabling the account and securing the interface.

---

## Exercise Setup & Execution Workflow

### Phase 1: Exercise Orchestration
1. Run the joint RvB setup script to start both the HMI simulator and the forensic environment:
   ```bash
   sudo ./setup.sh
   ```
2. The HMI Webstation will listen on port `10008` and the credential leak backup server will run on port `8081`.

### Phase 2: Active Red Attack
1. The Red Team enumerates the backup server on port `8081` to discover `backup/maint_notes_112.json`.
2. Red Team retrieves the credentials `contractor_maint` and cracks the leaked MD5 password hash to recover `Welcome123`.
3. Red Team authenticates to the Webstation HMI on port `10008`.
4. Red Team navigates to the restricted **Substation High Voltage Feeder** view and trips the breaker.

### Phase 3: Active Blue Detection & Mitigation
1. Blue Team monitors `/opt/scada/ScadaWeb/log/ScadaWeb.log` in real-time.
2. Blue Team detects the off-hours login from an external IP address.
3. Blue Team correlates the login with `/var/log/substation_maintenance/work_order_882_CLOSED.txt`.
4. Blue Team performs mitigation:
   * Disables the contractor account.
   * Restricts access to the backup directory.
   * Drafts an Incident Report based on the provided template.
