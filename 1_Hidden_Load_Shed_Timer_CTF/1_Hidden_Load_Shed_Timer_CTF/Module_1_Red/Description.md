# Scenario: Substation Zero (Red Team)

## 1. Operational Narrative
You are a red team operator conducting an assumed-breach simulation at a simulated power utility distribution center. You have successfully pivoted to an **Engineering Workstation** that has access to the primary load-shedding PLC (OpenPLC Runtime). 

The substation controls three critical distribution feeders:
* **Feeder 1** (mapped to physical coil `%QX0.0`)
* **Feeder 2** (mapped to physical coil `%QX0.1`)
* **Feeder 3** (mapped to physical coil `%QX0.2`)

Your intelligence indicates that a sudden total outage of all feeders will immediately trigger backup generators and network telemetry alarms, exposing your presence. To perform a stealthy process degradation attack, you must inject a hidden timer routine directly into the PLC's running logic that targets **Feeder 3** only.

---

## 2. Your Objectives
Your mission is to modify and deploy a custom Structured Text (ST) program that accomplishes the following goals:

1. **Keep Feeders 1 and 2 Online**: Both `FEEDER_1_CMD` (`%QX0.0`) and `FEEDER_2_CMD` (`%QX0.1`) must remain constantly energized (`TRUE`).
2. **Implement the Hidden Load-Shed Timer**:
   * `FEEDER_3_CMD` (`%QX0.2`) should normally run at `TRUE`.
   * An internal timer block must run in the background. After **60 seconds**, the timer should trigger, forcing `FEEDER_3_CMD` to `FALSE` (shedding the load).
   * Once the trip occurs, the logic must immediately reset the timer so it starts counting down for another 60 seconds, and restore the feeder state to `TRUE`.
3. **Compile and Deploy**: Upload the modified logic to the OpenPLC controller, compile it successfully, and confirm it runs in `RUN` mode.

---

* [ ] **Task 1: Create and Deploy the Reference Baseline**
  Create a Structured Text file named `baseline.st` (you can refer to the template in `engineering_baseline/baseline.st`) to configure the three critical feeders. Define the variables and force `FEEDER_1_CMD` (`%QX0.0`), `FEEDER_2_CMD` (`%QX0.1`), and `FEEDER_3_CMD` (`%QX0.2`) to `TRUE`.
* [ ] **Task 2: Access the Web Console & Deploy Baseline**
  Navigate to `http://localhost:8080` in your web browser. Log in using default credentials (`openplc` / `openplc`). Go to the **Programs** section, upload your `baseline.st` file, compile it, and confirm the PLC starts in `RUN` mode.
* [ ] **Task 3: Develop your attack payload**
  Create a new Structured Text file named `malicious.st`. Modify the baseline logic to implement the hidden load-shed timer on `FEEDER_3_CMD` as specified in the objectives.
* [ ] **Task 4: Upload and Compile the Payload**
  Upload your `malicious.st` file via the Web UI (or use the CLI/API script) and trigger the compilation. Verify the compiler log indicates success.
* [ ] **Task 5: Verify the Process Degradation**
  Go to the **Monitoring** dashboard. Confirm that all three coils start as `TRUE`, and that `FEEDER_3_CMD` briefly drops to `FALSE` for a single PLC scan cycle every 60 seconds.