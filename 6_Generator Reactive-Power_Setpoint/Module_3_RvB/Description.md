# Lab Briefing: Red vs Blue (RvB)

**Environment & Business Context:**
You are operating within the control network of a critical generator facility. The process heavily utilizes OPC UA to bridge the gap between engineering workstations and process field devices. Specifically, generation parameters—such as the reactive-power setpoint—are managed in real-time via this infrastructure. 

Company policy strictly mandates that these parameters remain within a mathematically approved operating band (5.0 to 15.0 Mvar) to ensure grid stability. Process alarms are integrated to alert operators of significant deviations. 

However, misconfigured access policies occasionally leave certain nodes vulnerable to unauthenticated parameter manipulation.

**Exercise Objective:**
*Red Objective:* Locate process-critical setpoints and induce a deviation by submitting parameter changes outside the accepted operating band.
*Blue Objective:* Monitor infrastructure logs, isolate unauthorized modifications, build a forensic timeline, and implement procedural defensive lockdowns.

*Context: MITRE ATT&CK for ICS T0836 (Modify Parameter) & TA0106 (Impair Process Control).*