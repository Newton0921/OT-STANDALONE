#!/bin/bash
# Module 2: Blue Participant Setup Script
echo "[*] Setting up Generator Reactive-Power Setpoint Lab (Blue)..."

# Generate Pre-seeded Forensic Artifacts
TS_BASE="2026-06-18T10:00:00.000000"
TS_READ="2026-06-18T10:15:00.000000"
TS_ATTACK="2026-06-18T10:22:45.123456"

# 1. Baseline Log
echo "[$TS_BASE] BASELINE | ReactivePowerSetpoint = 10.0 Mvar" > baseline_log.txt

# 2. Session Log
cat << EOF > session_log.txt
[$TS_BASE] SESSION OPEN | SessionID: ns=1;i=101 | IP: 192.168.10.50 | Token: Username
[$TS_READ] SESSION OPEN | SessionID: ns=1;i=102 | IP: 192.168.10.50 | Token: Username
[$TS_ATTACK] SESSION OPEN | SessionID: ns=1;i=105 | IP: 10.10.10.100 | Token: Anonymous
EOF

# 3. Write Event Log
echo "[$TS_ATTACK] WRITE EVENT | SessionID: ns=1;i=105 | NodeID: ns=2;i=5 | OldValue: 10.0 | NewValue: 75.0" > write_event_log.txt

# 4. Value-Change Log
echo "[$TS_ATTACK] VALUE CHANGE | NodeID: ns=2;i=5 | 10.0 -> 75.0" > value_change_log.txt

# 5. Process Alarm Log
echo "[$TS_ATTACK] ALARM | Type: DeviationAlarm | NodeID: ns=2;i=5 | ThresholdBreached: OUT OF BAND | AlarmValue: 75.0" > process_alarm_log.txt

echo "[*] Post-incident logs synthesized and ready for analysis."