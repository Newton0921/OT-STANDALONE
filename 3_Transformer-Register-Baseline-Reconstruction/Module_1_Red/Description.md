# Operation: Current Flow
**Role:** Red Team / OT Penetration Tester

During a security assessment of a power distribution substation, you have gained logical access to the Operational Technology (OT) network. Initial reconnaissance confirms that a Modbus TCP service is exposed on port 5020 and appears to belong to the transformer monitoring system.

Following a recent engineering workstation failure, the facility's Modbus register documentation was lost. While operators still possess a high-level process description, the exact Modbus address mapping for each process variable is unknown. Engineers also warn that several legacy engineering registers remain in the controller from previous commissioning activities, meaning not every populated register represents a live process value.

Your objective is to reconstruct the transformer's process register map by interacting with the live Modbus device. Use the available engineering documentation to understand the expected behaviour of the physical process, enumerate the Modbus data model, and observe the controller over time to distinguish genuine process variables from static decoy registers.

Identify the Modbus addresses corresponding to:

Transformer Load (MW)
Oil Temperature (°C)
Cooling Fan State
Breaker Position

Submit the discovered addresses in the following format:
LoadAddr-TempAddr-FanAddr-BreakerAddr