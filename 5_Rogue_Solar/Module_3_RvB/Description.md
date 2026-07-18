# Scenario: Red vs. Blue Operations

You are participating in a joint Red vs. Blue operational exercise simulating a grid-connected SCADA/OT telemetry infrastructure. Downstream grid operations rely on a real-time energy dashboard displaying cumulative photovoltaic power generation (in kW) sourced via an MQTT telemetry pipeline. 

### Exercise Context
A legitimate solar telemetry publisher updates photovoltaic generation status every 10 seconds under the client identity `solar_publisher_site7` to the topic `grid/solar/site7/kw`. Operators trust the broker’s state implicitly to make grid stability and load balancing decisions.

### Objective
- **Red Team:** Manipulate the generation status reported on the dashboard by injecting a forged generation value. The attack must bypass authorization controls and increase the perceived power output beyond actual ground truth by a defined target amount.
- **Blue Team:** Perform host and protocol analysis on the MQTT broker to detect the rogue publisher, isolate unauthorized connection and publish metadata, and identify the configuration vulnerability allowing unauthorized injection.

**Relevant Framework:** MITRE ATT&CK for ICS
* **Tactic:** Impair Process Control (TA0106)
* **Technique:** Unauthorized Message: Reporting Message (T1692.002)
