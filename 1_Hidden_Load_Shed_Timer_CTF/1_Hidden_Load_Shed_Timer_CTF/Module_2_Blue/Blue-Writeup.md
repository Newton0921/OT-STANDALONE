# Blue Team Manual Writeup: Forensic Investigation & Recovery

## 1. Operational Overview
The Blue Team is tasked with detecting, analyzing, and recovering from an unauthorized logic modification (T0889) affecting Substation Zero. The primary symptoms include periodic load-shedding on Feeder 3 (`%QX0.2`) with no reported mechanical faults.

---

## 2. Step-by-Step Forensic Walkthrough

### Step 1: Observing runtime anomalies
1. Navigate to the OpenPLC Monitoring Web interface at `http://localhost:8080` (log in with `openplc` / `openplc`).
2. Go to the **Monitoring** page.
3. Keep track of register `%QX0.2` (`FEEDER_3_CMD`). Observe that it periodically transitions from `TRUE` to `FALSE` for a brief instant every 60 seconds.
4. If monitoring via Modbus TCP (port 502), you can query the coil states continuously.

### Step 2: Analyzing Application Logs
1. Access the log files on the forensic workstation at `./evidence_logs/openplc_audit.log` (or retrieve the log from the running container `/docker_persistent/openplc_audit.log`):
   ```bash
   podman cp openplc_blue:/docker_persistent/openplc_audit.log ./openplc_audit.log
   cat ./openplc_audit.log
   ```
2. **Key Indicators of Compromise (IOCs) found:**
   * **Admin Login Event:** Log entries indicate an admin session established from an unexpected source IP (`10.10.50.15`).
   * **Unauthorized Override:** A warning message stating: `SYSTEM: active_program.st overwritten via WebAPI`.
   * **Unscheduled Restart:** Immediately following the override, the logs show: `SYSTEM: OpenPLC Runtime Restart Triggered`.

---

## 3. Technical Integrity Verification

### Step 3: Cryptographic Hash Comparison
1. Export the active program directly from the running container:
   ```bash
   podman cp openplc_blue:/docker_persistent/st_files/active_malicious.st ./pulled_active.st
   ```
2. Generate the SHA-256 hash of the pulled file and compare it to the baseline hash:
   ```bash
   # Calculate active program hash
   sha256sum ./pulled_active.st
   
   # Read baseline hash from forensic workstation
   cat ./investigation/baseline_hash.txt
   ```
3. **Forensic Findings:**
   * **Baseline Hash:** `70d550c4046fa6f56d70a382b16f77886abb8cf5d9c7ad7d893db029452ab0ff`
   * **Active Hash:** `a2672a4c1c423405d20f9e3c5b550caac07d67af821f6a921ea1545819c61c9d`
   * **Verdict:** The hashes do not match, confirming program file integrity compromise.

### Step 4: Logic Diffing
Run a line-by-line diff to identify the exact code modifications:
```bash
diff -u ./investigation/baseline.st ./pulled_active.st
```

**Expected Diff Output:**
```diff
--- ./investigation/baseline.st
+++ ./pulled_active.st
@@ -4,6 +4,8 @@
     FEEDER_1_CMD AT %QX0.0 : BOOL := TRUE;
     FEEDER_2_CMD AT %QX0.1 : BOOL := TRUE;
     FEEDER_3_CMD AT %QX0.2 : BOOL := TRUE;
+  END_VAR
+  VAR
+    Malicious_Timer : TON;
+    Timer_Reset : BOOL := FALSE;
   END_VAR
   FEEDER_1_CMD := TRUE;
   FEEDER_2_CMD := TRUE;
-  FEEDER_3_CMD := TRUE;
+  Malicious_Timer(IN := NOT Timer_Reset, PT := T#60s);
+
+  IF Malicious_Timer.Q THEN
+      FEEDER_3_CMD := FALSE;
+      Timer_Reset := TRUE;
+  ELSE
+      FEEDER_3_CMD := TRUE;
+      Timer_Reset := FALSE;
+  END_IF;
 END_PROGRAM
```
This confirms that the timer block `Malicious_Timer` is executing every 60 seconds and driving `%QX0.2` to `FALSE`.

---

## 4. Remediation and Incident Response

### Step 1: Containment
1. Stop the compromised container:
   ```bash
   podman stop openplc_blue
   ```
2. Disable network access to port 8080 from non-admin networks.

### Step 2: Eradication
1. Remove the malicious Structured Text files from the PLC's persistent directory.
2. In a real-world scenario, rewrite the SQLite database records or deploy a fresh database to wipe any references to unauthorized programs.
3. Change default credentials (`openplc` / `openplc`) via the dashboard settings or SQL query directly:
   ```bash
   # Update SQLite database to set custom password
   # (Always change default credentials!)
   ```

### Step 3: Recovery & Re-baseline
1. Copy the known-good baseline program back to the PLC container:
   ```bash
   podman cp ./investigation/baseline.st openplc_blue:/docker_persistent/st_files/baseline.st
   ```
2. Set the active program pointer back to the baseline:
   ```bash
   podman exec openplc_blue bash -c "echo 'baseline.st' > /docker_persistent/active_program"
   ```
3. Update the SQLite database table `Programs` to reference `baseline.st`:
   ```bash
   podman exec openplc_blue python3 -c \
       "import sqlite3; conn = sqlite3.connect('/docker_persistent/openplc.db'); cur = conn.cursor(); cur.execute(\"INSERT OR REPLACE INTO Programs (Prog_ID, Name, Description, File, Date_upload) VALUES (18, 'baseline', 'Baseline program', 'baseline.st', 1527184953)\"); conn.commit(); conn.close()"
   ```
4. Restart the container to compile and execute the clean code:
   ```bash
   podman stop openplc_blue && sleep 2 && podman start openplc_blue
   ```
5. Verify register `%QX0.2` remains constantly `TRUE`.
