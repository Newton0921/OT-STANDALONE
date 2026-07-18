# Challenge: Contractor Account Reuse in the Control Room (Red Team)

**Background:**
You are targeting the control system of a regional electrical substation. Late last week, a third-party maintenance contractor was brought in to service the high-voltage feeder instrumentation. The maintenance window is officially closed, and normal operator activity has resumed. 

**Your Objective:**
Gain unauthorized access to the restricted substation control view. 

You suspect that poor account lifecycle management may have left the contractor's access intact. Your goal is to identify a way to recover these retained credentials and exploit them to bypass the substation's perimeter controls. 

* **Framework Mapping:** MITRE ATT&CK for ICS
* **Tactics:** TA0110 (Persistence), TA0109 (Lateral Movement)
* **Technique:** T0859 (Valid Accounts)