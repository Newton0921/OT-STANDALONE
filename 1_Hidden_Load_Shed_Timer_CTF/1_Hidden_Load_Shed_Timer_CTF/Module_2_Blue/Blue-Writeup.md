# Blue Team Walkthrough: Detecting a Modified Program

## Objective
Your goal is to detect and document a malicious modification to the PLC logic (T0889) that is causing unexpected load shedding on `FEEDER_3_CMD`. 

## Scoring Logic
**BLUE scores** by correctly identifying ALL FOUR of the following:
1. The added/changed ladder logic block containing the timer.
2. The affected output coil (`FEEDER_3_CMD`).
3. The download source (IP address and timestamp from logs).
4. The SHA-256 hash mismatch between the baseline and active project file.

## Step-by-Step Forensics

**Step 1: Observing Anomalies**
1. Access the OpenPLC web interface (`http://<TARGET_IP>:8081` or `8080` depending on your deployment port).
2. Log in with `openplc` / `openplc`.
3. Go to the **Monitoring** tab. You will see `%QX0.2` (Feeder 3) periodically drop to `FALSE` every 60 seconds, which contradicts normal operations.

**Step 2: Log Review**
1. Open the `./evidence_logs/openplc_audit.log` file on your forensic workstation.
2. You will spot an unauthorized logic upload and a runtime restart.
3. *Record the IP Address and Timestamp.* (Requirement #3)
<img width="885" height="197" alt="image" src="https://github.com/user-attachments/assets/ea6bdd65-095a-4579-b684-e799611a3d2f" />

**Step 3: Reconstruct Baseline & Export Active Program**
1. Reconstruct the clean engineering baseline program (`baseline.st`) based on the system design specifications (where Feeders 1, 2, and 3 are set to `TRUE`) and save it to `./investigation/baseline.st`:
   ```pascal
   PROGRAM baseline
     VAR
       FEEDER_1_CMD AT %QX0.0 : BOOL := TRUE;
       FEEDER_2_CMD AT %QX0.1 : BOOL := TRUE;
       FEEDER_3_CMD AT %QX0.2 : BOOL := TRUE;
     END_VAR
     FEEDER_1_CMD := TRUE;
     FEEDER_2_CMD := TRUE;
     FEEDER_3_CMD := TRUE;
   END_PROGRAM

   CONFIGURATION Config0
     RESOURCE Res0 ON PLC
       TASK TaskMain(INTERVAL := T#20ms, PRIORITY := 0);
       PROGRAM Inst0 WITH TaskMain : baseline;
     END_RESOURCE
   END_CONFIGURATION
   ```
2. Pull the live active (compromised) program from the running container:
   `podman cp openplc_blue:/docker_persistent/st_files/active_malicious.st ./investigation/pulled_active.st`
3. Run standard Linux hashes to compare them:
   `sha256sum ./investigation/baseline.st`
   `sha256sum ./investigation/pulled_active.st`
   <img width="858" height="152" alt="image" src="https://github.com/user-attachments/assets/614923e7-225e-4abe-b108-634081e2872d" />

5. Notice they do not match. *Record the hashes.* (Requirement #4)

**Step 4: Logic Diffing**
1. Run a Linux `diff` to spot the exact modification:
   `diff ./investigation/baseline.st ./investigation/pulled_active.st`
   <img width="697" height="557" alt="image" src="https://github.com/user-attachments/assets/0c095961-78b8-4e17-8302-564c47df6bdb" />

3. The output will clearly highlight the `Malicious_Timer : TON;` variable and the `IF Malicious_Timer.Q THEN` logic block. (Requirement #1)
4. The `diff` explicitly shows `FEEDER_3_CMD := FALSE;` as the targeted output. (Requirement #2)
