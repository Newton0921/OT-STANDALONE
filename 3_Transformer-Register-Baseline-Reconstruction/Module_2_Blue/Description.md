# Operation: Ghost in the Wires
**Role:** SOC Analyst / OT Defender

You are monitoring the security perimeter for an automated electrical substation via a Modbus TCP server. We have received an alert indicating an anomaly in the Modbus traffic. 

Your objective (MITRE T0801 - Monitor Process State / TA0102 - Discovery) is to investigate the local transaction logs (`./modbus_server.log`). Identify the unauthorized client, determine when they first breached the segment, and characterize their reconnaissance methodology against the normal baseline.