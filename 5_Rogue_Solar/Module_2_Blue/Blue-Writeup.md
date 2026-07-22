Blue Team Lab Walkthrough


Step 1: Initial Triage & Attacker Attribution
To isolate the origin of the anomalous dashboard spike, incident responders analyzed the Eclipse Mosquitto broker connection logs. By filtering for recent client handshakes during the incident window, responders identified an unauthorized external connection.

Forensic Command:

Bash
grep -i "New client connected" /tmp/mqtt_lab/log/mosquitto.log
Simulated Log Evidence:
<img width="916" height="150" alt="image" src="https://github.com/user-attachments/assets/e099adc7-f9f9-4617-a2d5-24b9ccb39997" />


Plaintext
1784509812: New client connected from 10.0.5.112 as rogue_solar_client (c1, k60).
Rogue Client ID: rogue_solar_client

Source IP Address: 10.0.5.112

Assessment: The attacker utilized a custom script or MQTT GUI client (e.g., MQTT Explorer) without attempting to obfuscate their Client ID or IP, indicating either an automated attack script or an internal network compromise.

<img width="770" height="646" alt="image" src="https://github.com/user-attachments/assets/94e87712-49e8-4786-82ab-a1b96a80d662" />


Step 2: Payload Identification & Scope Assessment
Once the attacker's Client ID was established, responders isolated all publishing activity associated with rogue_solar_client to determine the scope of data corruption.

Forensic Command:

Bash
grep -A 1 -i "rogue_solar_client PUBLISH" /tmp/mqtt_lab/log/mosquitto.log
Simulated Log Evidence:

Plaintext

<img width="922" height="105" alt="image" src="https://github.com/user-attachments/assets/92ae2729-5421-493e-b274-b5bf5ef71914" />


First Forged Payload: 150.00


<img width="772" height="645" alt="image" src="https://github.com/user-attachments/assets/00f88fb9-286b-44ea-b80a-6da9871637f7" />


Assessment: The attacker successfully published an unencrypted, unvalidated floating-point payload directly to the active production telemetry topic, which the broker immediately fanned out to the EMS dashboard monitor.

Step 3: Ground-Truth Correlation & Anomaly Proof
In ICS/OT environments, digital logs must always be validated against physical reality. Responders cross-referenced the broker logs with the physical solar array's local inverter ground-truth logs (ground_truth.log).

Forensic Command:

Bash
cat /tmp/mqtt_lab/log/ground_truth.log | grep -C 2 "1784509815"
Simulated Log Evidence:

Plaintext
[1784509810] INVERTER_01: Status=OK | Output=49.85_kW | Irradiance=620_W/m2
[1784509815] INVERTER_01: Status=OK | Output=49.88_kW | Irradiance=621_W/m2  <-- PHYSICAL REALITY
[1784509820] INVERTER_01: Status=OK | Output=49.91_kW | Irradiance=622_W/m2
Anomaly Evidence: Impossible Rate-of-Change.

Technical Analysis: Solar inverters are bound by physical laws and ramping constraints; power output cannot jump from 49.88 kW to 150.00 kW instantaneously without a corresponding 300% spike in solar irradiance or inverter capacity. This discrepancy confirms a network-layer telemetry injection attack rather than a physical sensor malfunction.

4. Root Cause Analysis (RCA)
The breach was not caused by a zero-day vulnerability or advanced cryptographic break, but rather by broken access control and missing authentication within the MQTT broker configuration.

1. Anonymous Authentication Enabled
Inspection of /

<img width="917" height="131" alt="image" src="https://github.com/user-attachments/assets/f6307321-7376-4de5-9b6a-b0edf31666a1" />

sudo cat tmp/mqtt_lab/config/mosquitto.conf revealed:

<img width="823" height="42" alt="image" src="https://github.com/user-attachments/assets/ea6f28e3-b92d-465c-8f0b-987dbcd88941" />

Ini, TOML
allow_anonymous true
This setting instructed the broker to accept TCP connections from any IP address reaching port 1883 without challenging the client for a username, password, or cryptographic certificate.



