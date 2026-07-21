# Red Team Walkthrough: Contractor Account Reuse in the Control Room

## Objective
Exfiltrate leaked credentials belonging to an external maintenance contractor from an unsecured internal backup directory, bypass perimeter security on the substation HMI Webstation, and access a restricted High-Voltage Feeder view.

## Scenario Details
* **Target IP:** `<Target-IP>` (or `127.0.0.1` locally)
* **Webstation HMI Port:** `10008`
* **Backup/Internal Dev Server Port:** `8081`
* **Target Account:** `contractor_maint`

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
   curl -s http://127.0.0.1:8081/backup/
   ```
   <img width="607" height="198" alt="image" src="https://github.com/user-attachments/assets/92242666-3428-46e8-975c-ef16ee279a11" />

2. You will observe a directory listing containing a contractor maintenance notes log: `maint_notes_112.json`.
3. Fetch and read the contents of this JSON file:
   ```bash
   curl -s http://127.0.0.1:8081/backup/maint_notes_112.json
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
   <img width="875" height="200" alt="image" src="https://github.com/user-attachments/assets/e2441945-662f-4d63-b3c5-d6cdf6746393" />

4. **Key Findings & Password Cracking:**
   * **Username:** `contractor_maint`
   * **Leaked Password Hash:** `133987b0b6ad0c01fc0ccbdae1b95449` (MD5)
   * **Cracking the Hash:** Use an offline lookup database or tool (e.g., CrackStation or hashcat/john) to crack the MD5 hash. Cracking it reveals the cleartext password: `Welcome123`.
   * **Forensic Clue:** The work order was marked `CLOSED`, but the notes indicate that the account is "Awaiting active directory de-provisioning", suggesting poor account lifecycle management (MITRE ATT&CK T0859 - Valid Accounts).
     <img width="896" height="806" alt="image" src="https://github.com/user-attachments/assets/31114e70-f59a-4a9f-ab6d-e50628fdcfb5" />


### Step 3: Exploiting Valid Accounts to Bypass HMI Perimeter
1. Open your web browser and navigate to the Rapid SCADA Webstation login portal:
   `http://<Target-IP>:10008`
2. Enter the exfiltrated credentials:
   * **Username:** `contractor_maint`
   * **Password:** `Welcome123`
   <img width="571" height="437" alt="image" src="https://github.com/user-attachments/assets/54937a08-d4a8-45b7-bdc5-254078ffa164" />

3. Click **ESTABLISH SESSION**.
4. The system authorizes the session, granting access to the primary HMI cockpit.

### Step 4: Accessing the Restricted Control Panel & Executing Process Control 
1. Examine the left-hand navigation sidebar. Unlike a standard operator session, the contractor account retains access to a restricted section.
2. In the sidebar, click on **🚨 Restricted Feeder**. This navigates to `/Substation_High_Voltage_Feeder` (ViewID: 102).
3. Notice that the flag is initially locked with the message: **🔒 CRITICAL ARTIFACT LOCKED**.
4. Since the HMI control buttons have been removed and the backend API enforces security controls, you must interact with the control API directly. To ensure command integrity, the endpoint requires:
<img width="1012" height="945" alt="image" src="https://github.com/user-attachments/assets/6d439944-9a58-4003-903f-37a88f0865cb" />


   
Step 5: Execute OT Payload via Modbus TCP
Send the command directly to the Modbus gateway to trip breaker CB-301 by writing value 0 to Holding Register 4:

Bash
from pymodbus.client import ModbusTcpClient

client = ModbusTcpClient('127.0.0.1', port=5020)
client.connect()

# Write '0' (Open/Trip) to holding register 4 (Breaker CB-301 Control)
client.write_register(4, 0)
client.close()
print("Breaker CB-301 tripped!")


<img width="263" height="18" alt="image" src="https://github.com/user-attachments/assets/cd9ca95d-3958-44e2-a04d-b52594668120" />



