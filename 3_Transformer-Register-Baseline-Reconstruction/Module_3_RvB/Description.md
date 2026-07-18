# Operation: Baseline Paradigm (RvB Exercise)
**Environment:** Substation Transformer Instrumentation Network

The network segment simulating our transformer bay relies on Modbus TCP. It continuously measures four critical process variables: Load (MW), Oil Temperature (C), Cooling Fan status, and Breaker position. A central whitelist architecture allows only approved telemetry masters to poll this data to establish an operational baseline.

**Red Team Context:** As an adversary inside the network, your goal is to discover the specific memory addresses that control and report these physical states (T0801/TA0102) amidst decoy sensors. You must build an accurate map of the environment.

**Blue Team Context:** As the SOC monitoring the physical infrastructure, you are tasked with identifying unauthorized clients attempting to map the register layout. You must analyze the Modbus transaction logs to trace the reconnaissance, detect the start time of the event, and extract exactly how the adversary is probing the system.

Both teams must operate cleanly, document their evidence strictly, and outpace the other in achieving their tactical objectives.